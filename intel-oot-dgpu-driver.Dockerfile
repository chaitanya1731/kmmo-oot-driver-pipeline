ARG DTK_AUTO=image-registry.openshift-image-registry.svc:5000/openshift/driver-toolkit:latest
ARG KERNEL_FULL_VERSION=4.18.0-372.19.1
FROM ${DTK_AUTO} as builder

WORKDIR /build/
RUN dnf install -y patch gcc m4 make tar kmod findutils && dnf clean all

# install bison, package will be part of DTK image by default so this will be removed in future. 
ADD http://ftp.gnu.org/gnu/bison/bison-3.8.tar.gz /bison/
RUN tar -xzvf /bison/bison-3.8.tar.gz -C /bison/ && cd /bison/bison-3.8 && ./configure && make && make install

# install flex, package will be part of DTK image by default so this will be removed in future. 
ADD https://github.com/westes/flex/files/981163/flex-2.6.4.tar.gz /flex/
RUN tar -xzvf /flex/flex-2.6.4.tar.gz -C /flex/ && cd /flex/flex-2.6.4 && ./configure && make && make install

# build cse driver, latest version, public release
RUN git clone -b rhel86 https://github.com/intel-gpu/intel-gpu-cse-backports.git && cd intel-gpu-cse-backports && make && make modules_install

# build pmt driver, latest version, public release
RUN git clone -b rhel86 https://github.com/intel-gpu/intel-gpu-pmt-backports.git && cd intel-gpu-pmt-backports && export OS_TYPE=rhel_8 && export OS_VERSION="8.6" && make && make modules_install

# build i915 driver, latest version, public release
RUN git clone -b redhat/main https://github.com/intel-gpu/intel-gpu-i915-backports.git && cd intel-gpu-i915-backports && export LEX=flex; export YACC=bison && cp defconfigs/drm .config && make olddefconfig && make -j $(nproc) && make modules_install

# Firmware
RUN git clone https://github.com/intel-gpu/intel-gpu-firmware.git

FROM registry.access.redhat.com/ubi8/ubi-minimal:latest
RUN microdnf -y install kmod
COPY --from=builder /etc/driver-toolkit-release.json /etc/
COPY --from=builder /lib/modules/$KERNEL_FULL_VERSION/ /opt/lib/modules/$KERNEL_FULL_VERSION/
COPY --from=builder /build/intel-gpu-firmware/firmware/ /i915/
RUN depmod -b /opt
