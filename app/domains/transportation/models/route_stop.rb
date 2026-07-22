module Transportation
  class RouteStop < ApplicationRecord
    self.table_name = "route_stops"

    belongs_to :institution, class_name: "Core::Institution"
    belongs_to :route, class_name: "Transportation::Route", inverse_of: :route_stops
    has_many :route_riders, class_name: "Transportation::RouteRider", foreign_key: :route_stop_id,
             dependent: :nullify, inverse_of: :route_stop

    validates :name, presence: true
    validates :position, presence: true, uniqueness: { scope: :route_id }
  end
end
