using ErcotMagic, AIHelpMe

"""
Generates a new index for the YOURPACKAGE package - allow AI to answer questions about the package.
# Example of how this works 
#new_index = PT.Experimental.RAGTools.build_index(ErcotMagic)
# serialize(new_index, "ErcotMagic.jls")
## Load this as the main index for the package
result = AIHelpMe.aihelp("How do I query using ErcotMagic?", return_all=true)
AIHelpMe.pprint(result)
# Now, write some code 
cb = AIHelpMe.AICode(result)
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