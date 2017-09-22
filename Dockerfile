FROM ruby:2.4.2

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN echo "deb http://ftp.us.debian.org/debian jessie main contrib non-free" | tee -a /etc/apt/sources.list \
 && echo "deb http://security.debian.org/ jessie/updates contrib non-free" | tee -a /etc/apt/sources.list \
 && apt-get update \
 && apt-get install -y ttf-freefont ttf-mscorefonts-installer ttf-bitstream-vera ttf-dejavu ttf-liberation libfreetype6 libfontconfig1 nodejs npm imagemagick \
 && echo "export phantomjs=/usr/bin/phantomjs" > .bashrc \
 && ln -s /usr/bin/nodejs /usr/bin/node \
 && npm install -g phantomjs-prebuilt@2.1.15 casperjs@1.1.1

# gem install all dependencies ahead of time
RUN gem install aws-sdk --no-rdoc --no-ri \
  && gem install rake -v ">=0.9.2" \
  && gem install rdoc -v ">=3.12" \
  && gem install rspec -v "~> 2.9.0" \
  && gem install "fakeweb" -v ">=1.3.0" \
  && gem install "redis" -v ">=2.2.0" \
  && gem install "mongo" -v ">=1.3.1" \
  && gem install "bson_ext" -v ">=1.3.1" \
  && gem install "sqlite3" -v ">=1.3.4" \
  && gem install "robotex" -v ">= 1.0.0" \
  && gem install thor pry casperjs image_size \
  && gem install nokogiri -v '>= 1.8.0' \
  && gem install log4r parallel \
  && gem install mini_portile2 -v ">= 2.0.0"

COPY . /opt/wraith
RUN cd /opt/wraith/medusa/ && /opt/wraith/medusa/install-new-gem.sh \
 && cd /opt/wraith/ && /opt/wraith/install-new-gem.sh
ENV DOCKERIZED=true

ENTRYPOINT [ "wraith" ]
