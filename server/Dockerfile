FROM ruby:3

WORKDIR /app

COPY Gemfile Gemfile.lock config.ru ./

RUN gem install bundler && \
    bundle config --global frozen 1 && \
    bundle install

COPY app.rb event_generator.rb ./
CMD exec bundle exec thin start
