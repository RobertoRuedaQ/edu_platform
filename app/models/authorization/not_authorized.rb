module Authorization
  # Raised by the hard gate (Authorization::Controller#authorize!) when the
  # current actor lacks the permission. Rescued in the controller into a
  # friendly 403 (app/views/errors/forbidden.html.erb).
  class NotAuthorized < StandardError
    attr_reader :permission_key

    def initialize(permission_key = nil)
      @permission_key = permission_key
      super(permission_key ? "No autorizado: #{permission_key}" : "No autorizado")
    end
  end
end
