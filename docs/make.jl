## Make Documentation 

#push!(LOAD_PATH,"../src/")

using Documenter, ErcotMagic

#makedocs(sitename="ErcotMagic.jl", format="html")

makedocs(sitename = "ErcotMagic.jl", authors = "Stefan Wojcik", 
modules = [ErcotMagic])#, format=Documenter.HTML(repolink = "https://github.com/stefanjwojcik/ErcotMagic")) #,checkdocs = :exports)
