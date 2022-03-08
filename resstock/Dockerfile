FROM nrel/openstudio:3.3.0

RUN apt update && \
    apt install -y software-properties-common

ENV TZ="America/Denver"

RUN add-apt-repository ppa:deadsnakes/ppa && \
    apt update && \
    DEBIAN_FRONTEND="noninteractive" apt install -y python3.9 python3.9-dev python3.9-distutils

RUN curl https://bootstrap.pypa.io/get-pip.py | python3.9

COPY . /opt/OpenStudio-HEScore

RUN cd /opt/OpenStudio-HEScore/hescore-hpxml && python3.9 -m pip install .