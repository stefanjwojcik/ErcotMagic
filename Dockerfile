FROM julia:1.10.4

# Create a non-root user
RUN useradd -ms /bin/bash juliauser && \
    usermod -aG sudo juliauser 

# Install python requirements for the project
RUN apt-get update && apt-get install -y python3 python3-pip python3-venv

# Install pinecone and other Python dependencies
RUN python3 -m venv /venv && \
    /venv/bin/pip install pandas numpy 

# Install Google Cloud SDK
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add - && \
    apt-get update && apt-get install -y google-cloud-sdk

# Create a directory for the service account key and set permissions
RUN mkdir -p /home/juliauser/.gcloud/

# Copy the service account key file into the container
#COPY /home/swojcik/.ercotmagic/nanocentury-credentials.json /root/.gcloud/key.json

# Set environment variables for Google Cloud SDK
ENV GOOGLE_APPLICATION_CREDENTIALS="/home/juliauser/.gcloud/key.json"

# Authenticate using the service account
#RUN gcloud auth activate-service-account --key-file=/root/.gcloud/key.json

# Set the project (replace 'your-project-id' with your actual project ID)
#RUN gcloud config set project nanocentury

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
RUN julia -e 'cd("/home/juliauser/ErcotMagic"); using Pkg; Pkg.add("Revise"); Pkg.activate("."); Pkg.instantiate();'

RUN mkdir -p /home/juliauser/.julia/config 
#COPY startup.jl /home/juliauser/.julia/config/startup.jl

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