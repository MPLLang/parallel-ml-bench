FROM ubuntu:16.04

# install basic utilities
# make python 2.7 default
# gcc/g++ 9 default
# install newer mlton
# install mpl-switch
# download repo and initialize, install mpl
RUN apt-get update -qq \
 && apt-get install -qq git build-essential libgmp-dev mlton mlton-tools vim time numactl curl jq zip \
 && apt-get install -qq python2.7 \
 && update-alternatives --install /usr/bin/python python /usr/bin/python2.7 1 \
 && update-alternatives --config python \
 && curl https://bootstrap.pypa.io/pip/2.7/get-pip.py > get-pip.py \
 && python get-pip.py \
 && python -m pip install numpy matplotlib \
 && apt-get install -qq python3 \
 && curl -O https://bootstrap.pypa.io/pip/3.5/get-pip.py \
 && python3 get-pip.py \
 && python3 -m pip install numpy matplotlib \
 && apt-get install -qq software-properties-common python-software-properties \
 && add-apt-repository ppa:ubuntu-toolchain-r/test -y \
 && apt-get update \
 && apt-get install -qq gcc-snapshot -y \
 && apt-get install -qq gcc-9 g++-9 \
 && update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-9 60 --slave /usr/bin/g++ g++ /usr/bin/g++-9

RUN git clone https://github.com/mlton/mlton.git /mlton \
 && cd /mlton \
 && git checkout on-20210117-release \
 && make \
 && make install


# install java 11
RUN yes | add-apt-repository ppa:openjdk-r/ppa \
 && apt-get -qq update \
 && yes | apt-get -qq install openjdk-11-jdk


RUN cd / \
 && apt-get install wget \
 && yes | wget https://go.dev/dl/go1.18.10.linux-amd64.tar.gz \
 && tar -xvf go1.18.10.linux-amd64.tar.gz \
 && echo export PATH="/go/bin/:\$PATH" >> ~/.bashrc \
 && cd /root/

RUN echo | bash -c "sh <(curl -fsSL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)" \
 && opam init --disable-sandboxing -y
RUN yes | eval $(opam env --switch=default) \
 && opam install dune -y
RUN eval $(opam config env) \
 && opam install ocaml-variants.5.0.1+trunk -y \
 && opam install domainslib.0.4.2 -y
RUN echo eval '$(opam env)' >> ~/.bashrc

RUN git clone https://github.com/MPLLang/mpl.git /root/mpl-em \
  && cd /root/mpl-em \
  && git checkout pldi23-artifact \
  && make

RUN git clone https://github.com/diku-dk/smlpkg /smlpkg \
 && cd /smlpkg \
 && MLCOMP=mlton make clean all \
 && make install \
 && export PATH="/smlpkg/bin:${PATH}" \
 && git clone https://github.com/MPLLang/mpl-switch.git /mpl-switch \
 && echo export PATH="/mpl-switch:\${PATH}" >> ~/.bashrc \
 && export PATH="/mpl-switch:${PATH}" \
 && git clone https://github.com/MPLLang/parallel-ml-bench.git /root/entanglement-manage \
 && cd /root/entanglement-manage  \
 && git checkout pldi-artifact  \
 && smlpkg sync \
 && (yes | ./init)


WORKDIR /root
