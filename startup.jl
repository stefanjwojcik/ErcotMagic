ENV["PYTHON"]="/venv/bin/python"
ENV["JULIA_NUM_THREADS"] = 8
ENV["JULIA_PKG_DEVDIR"] = "/home/workspace"

using Revise 

function restart()
    startup = """
        Base.ACTIVE_PROJECT[]=$(repr(Base.ACTIVE_PROJECT[]))
        Base.HOME_PROJECT[]=$(repr(Base.HOME_PROJECT[]))
        cd($(repr(pwd())))
        """
    cmd = `$(Base.julia_cmd()) -ie $startup`
    atexit(()->run(cmd))
    exit(0)
end
