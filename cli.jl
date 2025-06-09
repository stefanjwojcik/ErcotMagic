using Term
using DataFrames
using JSON
#using AiModeration
import PromptingTools as PT
using PromptingTools.Experimental.AgentTools: AICode
#import AIHelpMe as AHM
using AIHelpMe
using Serialization

global const MODEL = "claudeh"

### IMPORTANT:: SYSTEM PROMPT 
tpl = [PT.SystemMessage("You are a world-class Data Scientist for a renewable energy company using the Julia language. Your communication is brief and concise. You're precise and answer only when you're confident in the high quality of your answer and the code involved. 

There are several internal Julia tools available to you, including:
- 



.")
    PT.UserMessage("# Question\n\n{{ask}}")
    ]


const LOGO = """
____  _____  ____  ____   _____                  
| ===|| () )/ (__`/ () \\|_   _|                 
|____||_|\\_\\____)\\____/  |_|                   
 ____ __  _______  _     ____ _____  ____ ___ __ 
| ===|\\ \\/ /| ()_)| |__ / () \\| () )| ===| | () )
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
    system_message =
    "You are a virtual power market analyst with access to the latest knowledge via Context Information. 
    You can query data, analyze data, and provide insights based on the provided context.
    **Instructions:**
    - Answer the question based only on the provided Context.
    - If you don't know the answer, just say that you don't know, don't try to make up an answer.
    - Be brief and concise.
    **Context Information:**
    ---
    {{context}}
    ---
    "
    cfg = PT.Experimental.RAGTools.RAGConfig()

    newtmp = PT.TEMPLATE_STORE[:RAGAnswerFromContext]
    newtmp[1] = PT.SystemMessage(system_message)    ## Code history 
    

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
            println(Panel("Execute Last Piece of Code", title="Here is an example:", style="bold red"))
            code = AICode(AIHelpMe.LAST_RESULT, safe_eval=false)
            success_or_fail = code.success ? "Success" : "Failure"
            println(Panel(tprint("$(code.code)"), title="Executed Code", style="bold green"))
            if success_or_fail == "Success"
                println(Panel("Result: $(code.result)", title="Execution Result", style="bold green"))
            else
                println(Panel("Error: $(code.error)", title="Execution Error", style="bold red"))
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
            result = aihelp"$user_input" # This is the AIHelpMe call
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

############## LLM 

"""
Generates a new index for the ErcotMagic package - allow AI to answer questions about the package.
"""
function regenerate_index()
    # Create a new index
    if !isfile("ErcotMagic.jls")
        @info "No index file found. Building a new index..."
        new_index = PT.Experimental.RAGTools.build_index(ErcotMagic)
        # Serialize the index to a file
        serialize("ErcotMagic.jls", new_index)    
    else
        @info "Index file found. Rebuilding the index..."
    end
    AIHelpMe.load_index!("ErcotMagic.jls")
    @info "Index loaded successfully."
end

function handle_input!(user_input::String)
    result = AIHelpMe.aihelp("$user_input", return_all=true)    
    ## If some signal in the result, then execute the code
    # AIHelpMe.pprint(result)
    #cb = AIHelpMe.AICode(result)
    return result 
end

# Launch UI
#main()