require "json"
require_relative "support/user"
load config_path
autoload :Worker, "app/worker"

module App
  class User < Record
    ROLE = :admin

    def initialize(name, active: true, **options, &block)
      @name = name
      @active = active
      block.call(self) if block
    end

    private

    def token
      return @name.to_s
    end
  end
end

alias new_token token
undef old_token
