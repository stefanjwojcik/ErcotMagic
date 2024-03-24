# Ercot Magic Documentation

## Overview

This is the documentation for the Ercot Magic package.

You will need to obtain a token from the Ercot API to collect data. Go to the [Ercot API](https://data.ercot.com/) and request a token.

```julia
using ErcotMagic
token = get_auth_token()
```


```@contents 
Pages = ["index.md", "api.md"]

```

```julia-repl
token = get_auth_token()
```

```@meta
CurrentModule = ErcotMagic
```

```@autodocs
Modules = [ErcotMagic]
```
