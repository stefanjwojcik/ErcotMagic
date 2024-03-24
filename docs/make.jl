## Make Documentation 

using Documenter, ErcotMagic

#push!(LOAD_PATH,"../src/")
#makedocs(sitename="ErcotMagic.jl", format="html")

makedocs(sitename = "ErcotMagic.jl", authors = "Stefan Wojcik", 
modules = [ErcotMagic],checkdocs = :exports)
