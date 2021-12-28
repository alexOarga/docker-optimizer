#
# Docker file to create a Python Environment
#

FROM ubuntu:20.04 as buildoptimizer
ARG GRB_VERSION=9.5.0
ARG GRB_SHORT_VERSION=9.5

############################
# clone repository
############################
# Install git and download repository into /home/gurobi
RUN apt-get update \
    && apt-get install -y git \
    && rm -rf /var/lib/apt/lists/* \
    && mkdir -p /home/gurobi \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /home/gurobi
RUN git init \
    && git remote add origin https://github.com/alexOarga/docker-optimizer \
    && git fetch \
    && git checkout -t origin/master -f \
    && rm -rf .git

############################
# download gurobi
############################
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

############################
# download GLPK
############################
# Install glpk from http
# instructions and documentation for glpk: http://www.gnu.org/software/glpk/
WORKDIR /opt/glpk
RUN wget http://ftp.gnu.org/gnu/glpk/glpk-4.57.tar.gz \
	&& tar -zxvf glpk-4.57.tar.gz

## Verify package contents
# RUN wget http://ftp.gnu.org/gnu/glpk/glpk-4.57.tar.gz.sig \
#	&& gpg --verify glpk-4.57.tar.gz.sig
#	#&& gpg --keyserver keys.gnupg.net --recv-keys 5981E818

###############################################################################
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

# first we install gurobipy as root in order to get the license
# note: this is just for prototyping purposes. Proper way would be to copy license into the image.
RUN python -m pip install gurobipy==${GRB_VERSION}

############################
# create user user
############################
RUN adduser --disabled-password \
    --gecos "Default user" \
    --uid ${NB_UID} \
    ${NB_USER}

############################
# install jupyter (as root!)
############################
RUN pip install --no-cache-dir notebook

# update system and certificates
RUN apt-get update \
    && apt-get install --no-install-recommends -y\
       ca-certificates  \
       p7zip-full \
       zip \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*

############################
# copy downloaded files
############################
WORKDIR /opt/gurobi
COPY --from=buildoptimizer /opt/gurobi /opt/gurobi
COPY --from=buildoptimizer /opt/glpk /opt/glpk
COPY --from=buildoptimizer /home/gurobi /home/gurobi

ENV GUROBI_HOME /opt/gurobi/linux64
ENV PATH $PATH:$GUROBI_HOME/bin
ENV LD_LIBRARY_PATH $GUROBI_HOME/lib

############################
# install gurobi
############################
WORKDIR /opt/gurobi/linux64
#run the setup
RUN python setup.py install

ENV GRB_LICENSE_FILE=/usr/local/lib/python3.8/site-packages/gurobipy/.libs/gurobi.lic

############################
# install glpk
############################
WORKDIR /opt/glpk/glpk-4.57
RUN ./configure \
	&& make \
	&& make check \
	&& make install \
	&& make distclean \
	&& ldconfig \
# Cleanup
	&& rm -rf /opt/glpk/glpk-4.57.tar.gz \
	&& apt-get clean

############################
# install python libraries
############################
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
ENV PATH="/home/${NB_USER}/.local/bin:${PATH}"

############################
# setup permissions
############################
# Return to root user
USER root

# Change /home/gurobi permissions to make the user we created the owner
USER root
RUN chown -R ${NB_UID} ${HOME}
USER ${NB_USER}

# start directory at home
WORKDIR ${HOME}

ENTRYPOINT [ ]

CMD ["--notebook-dir=/home/gurobi", "--NotebookApp.token=''","--NotebookApp.password=''"]

EXPOSE "8888"
