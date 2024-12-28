FROM r-base:4.4.2

# Install system dependencies
RUN apt-get update -qq && apt-get install -y \
    libcurl4-openssl-dev \
    libssl-dev \
    libxml2-dev \
    libsodium-dev \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Install remotes, plumber, and readr R packages
RUN R -e "install.packages('remotes', repos='https://cloud.r-project.org')" && \
    R -e "remotes::install_cran('plumber')" && \
    R -e "remotes::install_cran('readr')"

# Set working directory inside the container
WORKDIR /app

# Copy the entire local "app" directory to the container's /app directory
COPY ./app /app

# Expose the port that the API will run on
EXPOSE 8000

# Run the plumber API when the container starts
CMD ["Rscript", "-e", "pr <- plumber::plumb('api.R'); pr$run(host='0.0.0.0', port=8000)"]
