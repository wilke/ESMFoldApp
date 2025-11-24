# ESMFold + PATRIC Runtime Integrated Container
#
# Multi-stage build integrating BV-BRC PATRIC runtime with working ESMFold container
# Based on CEPI cepi-dev-optimized.dockerfile pattern
#
# Build: docker build --platform linux/amd64 -f container/esmfold-patric.dockerfile -t esmfold:patric .
# Test:  docker run --rm --platform linux/amd64 esmfold:patric perl -MBio::KBase::AppService::AppScript -e 'print "OK\n"'

# ============================================================================
# Stage 1: PATRIC Runtime Builder
# ============================================================================
FROM ubuntu:20.04 AS runtime-builder

LABEL stage=runtime-builder
LABEL description="Build PATRIC/BV-BRC Perl runtime and modules"

ENV DEBIAN_FRONTEND=noninteractive
ENV BASE=/opt/patric-common
ENV RT=$BASE/runtime
ENV TARGET=$RT
ENV BUILD_TOOLS=$RT/build-tools
ENV PERL_MM_USE_DEFAULT=1
ENV PERL_EXTUTILS_AUTOINSTALL="--defaultdeps"
ENV CPANM_OPTS="--quiet --notest --force --skip-satisfied"

# Set PATRIC runtime paths
ENV PATH=$RT/bin:$PATH
ENV PERL5LIB=$RT/lib/perl5:$PERL5LIB

# Install system dependencies for building PATRIC runtime
RUN apt-get -y update && apt-get -y install --no-install-recommends \
      # Build essentials
      autoconf \
      automake \
      build-essential \
      cmake \
      # Utilities
      ca-certificates \
      git \
      curl \
      wget \
      rsync \
      # Development libraries
      libdb-dev \
      libffi-dev \
      libgd-dev \
      liblzma-dev \
      libmysqlclient-dev \
      libncurses5-dev \
      libpng-dev \
      libreadline-dev \
      libsqlite3-dev \
      libxml2-dev \
      zlib1g-dev \
      # Perl and tools
      perl \
      cpanminus \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Create runtime directories
RUN mkdir -p $RT/bin $RT/lib $RT/etc $RT/man

# Clone and build runtime_build (Perl runtime only, minimal)
RUN cd / && \
    git clone --depth 1 https://github.com/BV-BRC/runtime_build && \
    cd runtime_build/runtime-modules/kb_perl_runtime && \
    perl build.perl $RT && \
    # Build modules with retries
    for i in 1 2 3; do \
      /usr/bin/perl build.modules -perl $RT/bin/perl && break || { \
        echo "Attempt $i failed, retrying in 5s..."; sleep 5; \
      }; \
    done && \
    # Cleanup
    rm -rf /root/.cpan /root/.cpanm /tmp/* /var/tmp/*

# Clone dev_container and checkout BV-BRC modules
RUN cd / && \
    git clone --depth 1 https://github.com/BV-BRC/dev_container.git && \
    cd dev_container && \
    ./checkout-bvbrc-modules && \
    ./bootstrap $RT && \
    . ./user-env.sh && \
    make && \
    # Cleanup build artifacts
    rm -rf /root/.cpan /root/.cpanm /tmp/* /var/tmp/*

# ============================================================================
# Stage 2: Final ESMFold + PATRIC Image
# ============================================================================
FROM esmfold:prod

LABEL maintainer="BV-BRC ESMFold + PATRIC Container"
LABEL description="ESMFold with BV-BRC PATRIC runtime for service integration"
LABEL version="1.0.0-patric"
LABEL org.opencontainers.image.source="https://github.com/wilke/ESMFoldApp"

ENV DEBIAN_FRONTEND=noninteractive

# Install system Perl packages for PATRIC compatibility
RUN apt-get -y update && apt-get -y install --no-install-recommends \
      perl \
      libfindbin-libs-perl \
      libjson-perl \
      libwww-perl \
      libio-socket-ssl-perl \
      libfile-slurp-perl \
      libdata-dumper-simple-perl \
      make \
      git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy PATRIC runtime and dev_container from builder stage
COPY --from=runtime-builder /opt/patric-common /opt/patric-common
COPY --from=runtime-builder /dev_container /dev_container
COPY --from=runtime-builder /runtime_build /runtime_build

# Set up BV-BRC/PATRIC environment variables
ENV BASE=/opt/patric-common
ENV RT=$BASE/runtime
ENV KB_TOP=/kb/deployment
ENV KB_RUNTIME=$RT
ENV KB_MODULE_DIR=/kb/module
ENV P3_WORKSPACE=/workspace
ENV IN_BVBRC_CONTAINER=1

# CRITICAL: APPEND PATRIC to PATH to preserve ESMFold's conda Python
# DO NOT PREPEND or ESMFold will break
ENV PATH_ORIGINAL=$PATH
ENV PATH=$PATH:/opt/patric-common/runtime/bin

# Set up PERL5LIB with all BV-BRC module paths
ENV KB_PERL_PATH=/dev_container/modules/app_service/lib:/dev_container/modules/Workspace/lib:/dev_container/modules/p3_core/lib:/dev_container/modules/p3_auth/lib:/dev_container/modules/p3_cli/lib:/dev_container/modules/p3_deployment/lib:/dev_container/modules/seed_core/lib:/dev_container/modules/seed_gjo/lib:/dev_container/modules/typecomp/lib:/dev_container/modules/sra_import/lib:/dev_container/modules/p3_user/lib:/dev_container/modules/p3_workspace/lib
ENV PERL5LIB=/opt/patric-common/runtime/lib/perl5:$KB_PERL_PATH

# Copy service files into container
COPY service-scripts/App-ESMFold.pl /service-scripts/
COPY app_specs/ESMFold.json /app_specs/
COPY scripts/esm-fold-wrapper /scripts/

# Make scripts executable
RUN chmod +x /service-scripts/App-ESMFold.pl /scripts/esm-fold-wrapper

# Create necessary directories
RUN mkdir -p /kb/deployment /kb/module /workspace

# Fix TORCH_HUB deprecation warning
ENV TORCH_HOME=/data/cache/

# Verify installations
RUN echo "=== Verifying ESMFold ===" && \
    conda run -n esmfold python -c "import sys; import torch; import esm; print(f'Python: {sys.version}'); print(f'PyTorch: {torch.__version__}'); print(f'ESM: {esm.__version__}')" && \
    echo "=== Verifying PATRIC Perl ===" && \
    perl -v | head -2 && \
    echo "=== Verifying BV-BRC Modules ===" && \
    perl -MBio::KBase::AppService::AppScript -e 'print "Bio::KBase::AppService::AppScript OK\n"' && \
    perl -MBio::P3::Workspace::WorkspaceClient -e 'print "Workspace client OK\n"' && \
    echo "=== Verifying CLI Tools ===" && \
    which p3-whoami || echo "p3-whoami not in default PATH (expected)"

# Default working directory
WORKDIR /workspace

# Entrypoint uses conda for ESMFold, but Perl/PATRIC available via shell
ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "esmfold"]
CMD ["esm-fold", "--help"]

# Health check - verify both ESMFold and PATRIC work
HEALTHCHECK --interval=60s --timeout=30s --start-period=120s --retries=3 \
    CMD conda run -n esmfold python -c "import esm; print('ESMFold OK')" && \
        perl -MBio::KBase::AppService::AppScript -e 'print "PATRIC OK\n"'
