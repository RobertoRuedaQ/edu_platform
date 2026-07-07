module Schedules
  # STUB room directory — no rooms table exists at all yet.
  # TODO: reemplazar por un modelo real de salones cuando exista.
  module RoomRoster
    Row = Data.define(:id, :name, :kind, :capacity, :building)

    def self.all
      [
        Row.new(id: "room-101", name: "Aula 101", kind: "classroom", capacity: 30, building: "Bloque A"),
        Row.new(id: "room-102", name: "Aula 102", kind: "classroom", capacity: 30, building: "Bloque A"),
        Row.new(id: "room-103", name: "Aula 103", kind: "classroom", capacity: 28, building: "Bloque B"),
        Row.new(id: "room-lab1", name: "Laboratorio 1", kind: "lab", capacity: 24, building: "Bloque B")
      ]
    end

    def self.find(id)
      all.find { |room| room.id == id.to_s }
    end
  end
end
