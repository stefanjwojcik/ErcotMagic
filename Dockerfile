FROM julia:1.10.4

# Create a non-root user
RUN useradd -ms /bin/bash juliauser && \
    usermod -aG sudo juliauser 

# Install python requirements for the project
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv

# Install pinecone and other Python dependencies
RUN python3 -m venv /venv && \
    /venv/bin/pip install pandas numpy 

# Switch to the non-root user
USER juliauser

# Set the working directory
WORKDIR /home/juliauser

# Activate the virtual environment
RUN echo 'export PATH="/venv/bin:$PATH"' >> /home/juliauser/.bashrc

RUN mkdir -p /home/juliauser/.julia/config && \
    echo 'ENV["PYTHON"] = "/venv/bin/python"' >> /home/juliauser/.julia/config/startup.jl

# Copy the rest of the project files
COPY . /home/juliauser/ErcotMagic

# Install Julia packages in the project environment
RUN julia -e 'cd("/home/juliauser/ErcotMagic"); using Pkg; Pkg.activate("."); Pkg.instantiate();'

RUN mkdir -p /home/juliauser/.julia/config 
COPY startup.jl /home/juliauser/.julia/config/startup.jl

# Set the environment variable for Python
#ENV PATH="/venv/bin:$PATH:/usr/local/julia/bin:/usr/local/bin"

# Ensure the virtual environment is activated
USER root
RUN /venv/bin/pip install --upgrade pip
USER juliauser

# Expose port 8080 to the outside world
EXPOSE 8080

# Set the default command to run your Julia function handler
CMD [ "julia", "--project=/home/juliauser/ErcotMagic", "-e", "include(\"scripts/daily_update_script.jl\")" ]