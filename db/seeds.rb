# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

User.create!(username: "testuser1", email: "testuser1@gmail.com", 
						password: "password", password_confirmation: "password")

playlist = Playlist.create!(title: "testPlaylist",
                user_id: 1)

5.times do |n|
  playlist.songs.create(title: "song#{n}")
end
  

99.times do |n|
	lat = Random.new.rand(33.906699..34.156027) 
	lng = Random.new.rand(-118.533987..-118.190153) 

  Playlist.create!(title:  "WADDDUPPPP#{n}",
               user_id: 1,
               created_at:  DateTime.now,
               updated_at:  DateTime.now,
               latitude: lat,
               longitude: lng
               )
end