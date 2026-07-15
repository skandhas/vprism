module Store
  class User < Record
    ROLE = :admin

    def initialize(name)
      @name = name
    end

    def active?
      true
    end
  end
end
