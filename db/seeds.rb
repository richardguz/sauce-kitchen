# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: 'Star Wars' }, { name: 'Lord of the Rings' }])
#   Character.create(name: 'Luke', movie: movies.first)

5.times do |n|
  User.create!(username: "testuser#{n}", email: "testuser#{n}@gmail.com", 
  						password: "password", password_confirmation: "password")
end

playlist = Playlist.create!(title: "testPlaylist1",
                user_id: 1)
Playlist.create!(title: "testPlaylist2",
                user_id: 1)

Like.create!(user_id: 1, playlist_id: 1)
Like.create!(user_id: 1, playlist_id: 2)
Like.create!(user_id: 2, playlist_id: 1)
Like.create!(user_id: 2, playlist_id: 2)
Like.create!(user_id: 3, playlist_id: 1)
Like.create!(user_id: 4, playlist_id: 1)
Like.create!(user_id: 5, playlist_id: 1)

possibleSongs = [132201186]
5.times do |n|
  song = playlist.songs.create(name: "queued-song#{n}", deezer_id: possibleSongs[Random.rand(possibleSongs.size)])
  psong = Psong.find_by(song_id: song.id, playlist_id: playlist.id)
  psong.update_column(:queued, true)
  psong.update_column(:upvotes, Random.rand(15))
end

5.times do |n|
  song = playlist.songs.create(name: "waiting-song#{n}", deezer_id: possibleSongs[Random.rand(possibleSongs.size)])
  psong = Psong.find_by(song_id: song.id, playlist_id: playlist.id)
  psong.update_column(:queued, false)
  psong.update_column(:upvotes, Random.rand(15))
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