using Term
using DataFrames
using JSON
#using AiModeration
import PromptingTools as PT
import AIHelpMe as AHM
using Serialization

global const MODEL = "claudeh"


const LOGO = """
____ _____  ____  ____  _____                  
| ===|| () )/ (__`/ () \\|_   _|                 
|____||_|\\_\\____)\\____/  |_|                   
 ____ __  _______  _     ____ _____  ____ _____ 
| ===|\\ \\/ /| ()_)| |__ / () \\| () )| ===|| () )
|____|/_/\\_\\|_|   |____|\\____/|_|\\_\\|____||_|\\_\

          ERCOT Explorer
"""

function print_centered_logo()
    width = displaysize(stdout)[2]
    lines = split(LOGO, '\n')
    centered_lines = [
        lpad(line, div(width + length(line), 2)) for line in lines
    ]
    return centered_lines
end

const CENTERED_LOGO = print_centered_logo()


logo_and_info = join(CENTERED_LOGO, "\n") * "\n\n" * """
ERCOT Explorer

Natural language Power Market Data Analysis
ERCOT Explorer is a tool that allows you to interact with ERCOT data using natural language.

Type 'intro' for a brief introduction
Type 'help' for available commands
Type 'exit' to quit
"""

logo_banner = Panel(
    logo_and_info,
    title="Welcome To",
    style="bold yellow",
    fit=true,
)


function render_welcome()
    # Print the logo and info
    println(Panel(logo_banner, style="bold blue", fit=true))
    println()
end

function show_intro()
    intro_text = """
    Hello! 

    To get started, please ask me about what I am and what I can do. 

    Here are some examples of what you can ask me:

    - "What are you and what can I use you for?"
    - "How does this work? How do I use this?"
    - "What data is available?"
    
    Type 'help' for available commands or 'exit' to quit.
    """
    println(Panel(intro_text, title="Introduction", style="yellow", fit=true))
end

function show_help()
    help_text = """
    Available commands:
    
    - intro: Show the introduction message
    - try again: Try the last command again
    - clear: Clear the console
    - help: Show this help message
    - example: Run through an example policy
    - exit/quit: Exit the application
    """
    
    println(Panel(help_text, title="Help", style="blue", fit=true))
end

function thinking_spinner(task::Function)
    # Unicode squares for rotation
    squares = ["■", "▣", "□", "▢"]
    # ANSI escape for blue
    blue = "\033[34m"
    reset = "\033[0m"
    msg = " thinking..."
    running = Ref(true)
    result = nothing

    spinner_task = @async begin
        i = 1
        while running[]
            print("\r$(blue)$(squares[i])$(reset)$msg")
            flush(stdout)
            sleep(0.15)
            i = i == length(squares) ? 1 : i + 1
        end
        # Clear the line after done
        print("\r" * " " ^ (length(msg) + 4) * "\r")
        flush(stdout)
    end

    try
        result = task()
    finally
        running[] = false
        wait(spinner_task)
    end
    return result
end

function main()
    Term.Consoles.clear()  # <-- Use the correct clear function
    # Banner
    render_welcome()
    # Show intro
    show_intro()
    ## Set up Information to query 
    regenerate_index()

    # Set up an initial system message 
    system_message = PT.SystemMessage(
        """You are an ERCOT (Electric Reliability Council of Texas) data analysis query parser. Your job is to parse natural language requests about ERCOT electricity market data and convert them into structured JSON instructions for a Julia-based analysis system.
    Your Role

    Parse user requests for ERCOT data analysis tasks
    Extract key parameters and intent from natural language
    Return structured JSON that can be executed by automated systems
    Handle ambiguous requests by making reasonable assumptions
    Provide clear error messages for impossible requests

    ERCOT Data Context
    ERCOT manages the Texas electrical grid and provides various data types:
    Load Data: Electricity demand (actual and forecast)

    Measured in MW (megawatts)
    Available by weather zone: COAST, EAST, FARNORTH, NORTH, NCENT, SOUTH, SCENT, WEST, HOUSTON
    Updated every 15 minutes for actual, hourly for forecast

    Price Data (LMP - Locational Marginal Pricing):

    Real-time and day-ahead prices in USD/MWh
    Available for settlement points (major hubs and zones)
    Key hubs: HB_HOUSTON, HB_HUBAVG, HB_NORTH, HB_SOUTH, HB_WEST

    Generation Data:

    Power generation by fuel type and unit
    Fuel types: COAL, GAS, NUCLEAR, HYDRO, WIND, SOLAR, OTHER
    Real-time and historical generation output

    Ancillary Services:

    Regulation services, spinning reserves, non-spinning reserves
    Capacity and pricing data

    Available Intents

    FETCH_DATA: Retrieve raw data from ERCOT APIs
    VISUALIZE: Create plots, charts, dashboards
    ANALYZE: Statistical analysis, trends, patterns
    FORECAST: Predict future values using time series models
    SUMMARIZE: Generate summary statistics and reports
    COMPARE: Compare across time periods, regions, or metrics
    ALERT: Set up monitoring for specific conditions
    EXPORT: Save data or results to files

    Time Handling

    Support relative times: "last hour", "yesterday", "past week", "last month", "year to date"
    Support absolute dates: "January 2024", "March 15, 2024", "2023-2024 winter"
    Default timezone is Central Time (ERCOT's operating timezone)
    For forecasts, specify horizon: "next 24 hours", "tomorrow", "next week"

    Analysis Types
    Statistical: Basic stats, distributions, percentiles
    Seasonal: Identify seasonal patterns and cycles
    Anomaly: Detect unusual patterns or outliers
    Correlation: Relationships between variables
    Trend: Long-term directional changes
    Peak: Identify and analyze peak demand/price periods
    Forecast_Accuracy: Compare forecasts to actual values
    Output Formats

    plot: Interactive visualizations
    table: Tabular data display
    summary: Text summary with key insights
    export: Save to file (CSV, JSON, etc.)
    dashboard: Multi-panel interactive view

    """)
    conversation = [
        PT.SystemMessage(system_message), 
        PT.UserMessage("What are you and what can I use you for?"),
    ]


    # Prompt
    running = true
    while running
        print("\e[36mExplorer> \e[0m")
        
        user_input = readline()
        
        if isempty(user_input)
            continue
        elseif lowercase(user_input) in ["exit", "quit"]
            running = false
            continue
        elseif lowercase(user_input) == "help"
            push!(conversation_context, PT.AIMessage("User asked for help"))
            show_help()
            continue
        elseif lowercase(user_input) == "example"
            println(Panel("EXAMPLE TBD", title="Here is an example:", style="bold red"))
            user_input = "My example is: $example"
        elseif lowercase(user_input) == "clear"
            Term.Consoles.clear()
            render_welcome()
            continue
        end

        # Render result in a debug‐friendly box
        println()
        ai_result = thinking_spinner() do
            # Simulate AI call (replace with actual AI call)
            #sleep(2)  # <-- Remove this and call your AI here
            # TODO: Add a catch here to split questions and execution
            #handle_input!(modcontext, user_input)
            push!(conversation, PT.UserMessage(user_input))
            result = AHM.aihelp("$user_input", return_all=true) 
            push!(conversation, PT.AIMessage(result.answer))
            result
        end
        Term.Panel(ai_result.question, title="You Asked", style="bold green", fit=true)
        Term.tprint(Term.parse_md(ai_result.answer))
        #println(Panel(Term.parse_md("$ai_result"), title="AI Response", style="bold blue"))
        println()

    end
    
    println(Panel("Thank you for using ERCOT EXPLORER!", 
                 title="Goodbye", 
                 style="blue bold", 
                 fit=true))

    # Send through AI
    #ai_result = ai"$user_input"
end

############## LLM 

"""
Generates a new index for the ErcotMagic package - allow AI to answer questions about the package.
"""
function regenerate_index()
    # Create a new index
    if !isfile("ErcotMagic.jls")
        @info "No index file found. Building a new index..."
        new_index = PT.Experimental.RAGTools.build_index([ErcotMagic])
        # Serialize the index to a file
        serialize("ErcotMagic.jls", new_index)    
    else
        @info "Index file found. Rebuilding the index..."
    end
    AHM.load_index!("ErcotMagic.jls")
    @info "Index loaded successfully."
end

function handle_input!(user_input::String)
    result = AHM.aihelp("$user_input", return_all=true)    
    ## If some signal in the result, then execute the code
    # AIHelpMe.pprint(result)
    #cb = AIHelpMe.AICode(result)
    return result 
end

# Launch UI
#main()