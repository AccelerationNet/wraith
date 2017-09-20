FROM ruby:2.4.2

# some of ruby's build scripts are written in ruby
# we purge this later to make sure our final image uses what we just built
RUN apt-get update
RUN echo "export phantomjs=/usr/bin/phantomjs" > .bashrc
RUN apt-get install -y libfreetype6 libfontconfig1 nodejs npm
RUN ln -s /usr/bin/nodejs /usr/bin/node
RUN npm install npm
RUN npm install -g phantomjs-prebuilt@2.1.15 casperjs@1.1.1

# gem install all dependencies ahead of time
RUN gem install aws-sdk --no-rdoc --no-ri
RUN gem install rake -v ">=0.9.2"
RUN gem install rdoc -v ">=3.12"
RUN gem install rspec -v "~> 2.9.0"
RUN gem install "fakeweb" -v ">=1.3.0"
RUN gem install "redis" -v ">=2.2.0"
RUN gem install "mongo" -v ">=1.3.1"
RUN gem install "bson_ext" -v ">=1.3.1"
RUN gem install "tokyocabinet" -v ">=1.29"
RUN gem install "kyotocabinet-ruby" -v ">=1.27.1"
RUN gem install "sqlite3" -v ">=1.3.4"
RUN gem install open-ended thor pry casperjs image_size robotext nokgiri log4r parallel

# Make sure decent fonts are installed. Thanks to http://www.dailylinuxnews.com/blog/2014/09/things-to-do-after-installing-debian-jessie/
RUN echo "deb http://ftp.us.debian.org/debian jessie main contrib non-free" | tee -a /etc/apt/sources.list
RUN echo "deb http://security.debian.org/ jessie/updates contrib non-free" | tee -a /etc/apt/sources.list
RUN apt-get update
RUN apt-get install -y ttf-freefont ttf-mscorefonts-installer ttf-bitstream-vera ttf-dejavu ttf-liberation

# Make sure a recent (>6.7.7-10) version of ImageMagick is installed.
RUN apt-get install -y imagemagick


copy . /opt/wraith
RUN cd /opt/wraith/medusa/ && /opt/wraith/medusa/install-new-gem.sh
RUN cd /opt/wraith/ && /opt/wraith/install-new-gem.sh
ENV DOCKERIZED=true


ENTRYPOINT [ "wraith" ]
