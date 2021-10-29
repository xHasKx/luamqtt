# image build command:
# docker build --pull --rm -f tests/Dockerfile -t luamqtt-run-tests:latest .

FROM ubuntu:20.04

# installing base dependencies, create hererocks for all lua versions, install all deps inside and finally cleanup
RUN apt-get update \
	&& apt-get install -y --no-install-recommends python3-pip build-essential libreadline8 libreadline-dev unzip curl libssl-dev git \
	&& pip install hererocks \
	&& mkdir /hererocks && cd /hererocks \
	&& hererocks l51 -l5.1 -rlatest \
	&& hererocks l52 -l5.2 -rlatest \
	&& hererocks l53 -l5.3 -rlatest \
	&& hererocks j20 -j2.0 -rlatest \
	&& hererocks j21 -j2.1 -rlatest \
	# lua5.1
	&& bash -c 'source /hererocks/l51/bin/activate \
		&& luarocks install luabitop \
		&& luarocks install luasocket \
		&& luarocks install luasec \
		&& luarocks install busted \
		&& luarocks install copas' \
	# lua5.2
	&& bash -c 'source /hererocks/l52/bin/activate \
		&& luarocks install luasocket \
		&& luarocks install luasec \
		&& luarocks install busted \
		&& luarocks install copas' \
	# lua5.3
	&& bash -c 'source /hererocks/l53/bin/activate \
		&& luarocks install luasocket \
		&& luarocks install luasec \
		&& luarocks install busted \
		&& luarocks install copas' \
	# luajit2.0
	&& bash -c 'source /hererocks/j20/bin/activate \
		&& luarocks install luasocket \
		&& luarocks install luasec \
		&& luarocks install busted \
		&& luarocks install copas' \
	# luajit2.1
	&& bash -c 'source /hererocks/j21/bin/activate \
		&& luarocks install luasocket \
		&& luarocks install luasec \
		&& luarocks install busted \
		&& luarocks install copas' \
	&& pip uninstall -y hererocks \
	&& apt-get purge -y python3 build-essential libreadline-dev unzip curl \
	&& apt-get autoremove -y \
	&& rm -rf /var/lib/apt/lists/*

# to run tests in the container manually - build the image with the following lines uncommented:
# RUN mkdir /luamqtt
# COPY mqtt /luamqtt/mqtt
# COPY tests /luamqtt/tests
# WORKDIR /luamqtt
# ENTRYPOINT [ "/bin/bash", "-c", "./tests/run-in-docker.sh" ]

# ... and run container with this image:
# docker run -ti luamqtt-run-tests:latest
