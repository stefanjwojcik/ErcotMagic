using Term
using DataFrames
using JSON
#using AiModeration
import PromptingTools as PT
using PromptingTools.Experimental.AgentTools: AICode
#import AIHelpMe as AHM
#using AIHelpMe
using Serialization

global const MODEL = "claudeh"

### IMPORTANT:: SYSTEM PROMPT 
PT.load_templates!("templates")

const LOGO = raw"""
____  _____  ____  ____  _____                  
| ===|| () )/ (__`/ () \|_   _|                 
|____||_|\_\ ____)\____/  |_|                   
 ____ __  _______  _     ____  _____  ____  _____ 
| ===|\ \/ /| ()_)| |__ / () \\| () )| ===| | () )
|____|/_/\_\|_|   |____\\____/ |_|\_\|____| |_|\_\

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
    ai_result = nothing
    
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
        elseif lowercase(user_input) == "execute"
            println(Panel("Execute Last Piece of Code", title="Here is your result:", style="bold red"))
            if @isdefined ai_result
                @info "Executing last AI result..."
            else
                @info "No previous AI result to execute."
                continue
            end
            code = AICode(ai_result, safe_eval=false)
            println(Panel("$(code.code)", title="Executed Code", style="bold green"))
            if isa(code.output, DataFrame)
                # Convert DataFrame to matrix for Term.Table
                table = display_small_df(code.output)
                println(Panel(table, title="Execution Result", style="bold green"))
            else
                println(Panel("Result: $(code.output)", title="Execution Result", style="bold green"))
            end
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
            result = PT.aigenerate(:ErcotMagicPrompt; ask="$user_input") # This is the AIHelpMe call
            result
        end
        Term.Panel(user_input, title="You Asked", style="bold green", fit=true)
        Term.tprint(Term.parse_md(ai_result.content))
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

### UTILS 

function display_small_df(df::DataFrame)
    if ncol(df) > 5
        # If more than 10 columns, display only the first 10
        df = select(df, 1:5)
        ellipsis_column = DataFrame("..." => fill("...", nrow(df)))
        df = hcat(df, ellipsis_column)
    end

    if nrow(df) > 10
        # If more than 10 rows, display only the first 10
        top_rows = first(df, 5)
        bottom_rows = last(df, 5)
        ellipsis_row = DataFrame(Dict(name => ["..."] for name in names(df)))
        df = vcat(top_rows, ellipsis_row, bottom_rows)
    end
    # Convert DataFrame to matrix for Term.Table
    df_matrix = Matrix(df)
    # Get column names for header
    col_names = names(df)
    table = Term.Table(df_matrix, header=col_names)
    return table
end

# Launch UI
#main()