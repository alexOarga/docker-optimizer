#
# Docker file to create a Python Environment
#

FROM ubuntu:20.04 as buildoptimizer
ARG GRB_VERSION=9.5.0
ARG GRB_SHORT_VERSION=9.5

# install gurobi package and copy the files
WORKDIR /opt

RUN apt-get update \
    && apt-get install --no-install-recommends -y\
       ca-certificates  \
       wget \
    && update-ca-certificates \
    && wget -v https://packages.gurobi.com/${GRB_SHORT_VERSION}/gurobi${GRB_VERSION}_linux64.tar.gz \
    && tar -xvf gurobi${GRB_VERSION}_linux64.tar.gz  \
    && rm -f gurobi${GRB_VERSION}_linux64.tar.gz \
    && mv -f gurobi* gurobi \
    && rm -rf gurobi/linux64/docs

# After the file renaming, a clean image is build
FROM python:3.8 AS packageoptimizer

ARG GRB_VERSION=9.5.0

LABEL vendor="Gurobi"
LABEL version=${GRB_VERSION}


# Create user as explained in: https://mybinder.readthedocs.io/en/latest/tutorials/dockerfile.html#preparing-your-dockerfile
ARG NB_USER=gurobi
ARG NB_UID=1000
ENV USER ${NB_USER}
ENV NB_UID ${NB_UID}
ENV HOME /home/${NB_USER}

# add user
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

# Install jupyter notebook
RUN pip install --no-cache-dir notebook

# update system and certificates
RUN apt-get update \
    && apt-get install --no-install-recommends -y\
       ca-certificates  \
       p7zip-full \
       zip \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/gurobi
COPY --from=buildoptimizer /opt/gurobi .

ENV GUROBI_HOME /opt/gurobi/linux64
ENV PATH $PATH:$GUROBI_HOME/bin
ENV LD_LIBRARY_PATH $GUROBI_HOME/lib

WORKDIR /opt/gurobi/linux64
#run the setup
RUN python setup.py install


# Install python libraries as jovyan user
USER jovyan
RUN python -m pip install \
        matplotlib \
        numpy \
        pandas \
        sklearn \
        folium \
        xlrd==1.2.0 \
    && python -m pip install gurobipy==${GRB_VERSION}

# Add installation folder to path
ENV PATH="/home/jovyan/.local/bin:${PATH}"

# Return to root user
USER root

# Change /home/gurobi permissions to make the user we created the owner
USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}

ENTRYPOINT [ ]

CMD ["--notebook-dir=/home/gurobi", "--NotebookApp.token=''","--NotebookApp.password=''"]
