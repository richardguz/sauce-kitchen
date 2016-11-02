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

user = User.create!(username: "testuser6", email: "testuser6@gmail.com", 
              password: "password", password_confirmation: "password")

playlist = Playlist.create!(title: "testPlaylist1",
                user_id: user.id)
Playlist.create!(title: "testPlaylist2",
                user_id: user.id)

Like.create!(user_id: 1, playlist_id: playlist.id)
Like.create!(user_id: 1, playlist_id: playlist.id)
Like.create!(user_id: 2, playlist_id: playlist.id)
Like.create!(user_id: 2, playlist_id: playlist.id)
Like.create!(user_id: 3, playlist_id: playlist.id)
Like.create!(user_id: 4, playlist_id: playlist.id)
Like.create!(user_id: 5, playlist_id: playlist.id)

possibleSongs = [
  {:name => "through the late night", :artist => "Travis Scott", :deezer_id => 132201186},
  {:name => "Love$ick", :artist => "Mura Masa", :deezer_id => 133193052},
  {:name => "Low", :artist => "Mura Masa", :deezer_id => 98744588},
  {:name => "Nightcrawler", :artist => "Travis Scott", :deezer_id => 106713882},
  {:name => "Broccoli", :artist => "D.R.A.M", :deezer_id => 123210948},
  {:name => "beibs in the trap", :artist => "Travis Scott", :deezer_id => 132201188},
  {:name => "goosebumps", :artist => "Travis Scott", :deezer_id => 132201196},
  {:name => "Tamale", :artist => "Tyler the Creator", :deezer_id => 65723693},
  {:name => "Dead Or Alive", :artist => "Jazz Cartier", :deezer_id => 107418050},
  {:name => "Chum", :artist => "Earl Sweatshirt", :deezer_id => 70018666},
  {:name => "Dat $tick", :artist => "Rich Chigga", :deezer_id => 120863156}
]

3.times do |n|
  tempSong = possibleSongs[Random.rand(possibleSongs.size)]
  song = playlist.songs.create(name: tempSong[:name], artist: tempSong[:artist], deezer_id: tempSong[:deezer_id])
  psong = Psong.find_by(song_id: song.id, playlist_id: playlist.id)
  psong.update_column(:queued, true)
  psong.update_column(:upvotes, Random.rand(15))
end

3.times do |n|
  tempSong = possibleSongs[Random.rand(possibleSongs.size)]
  song = playlist.songs.create(name: tempSong[:name], artist: tempSong[:artist], deezer_id: tempSong[:deezer_id])
  psong = Psong.find_by(song_id: song.id, playlist_id: playlist.id)
  psong.update_column(:queued, false)
  psong.update_column(:upvotes, Random.rand(15))
end
  

10.times do |n|
	lat = Random.new.rand(33.906699..34.156027) 
	lng = Random.new.rand(-118.533987..-118.190153) 

  Playlist.create!(title:  "WADDDUPPPP#{n}",
               user_id: user.id,
               created_at:  DateTime.now,
               updated_at:  DateTime.now,
               playing: true,
               latitude: lat,
               longitude: lng,
               )
end

# Following relationships
users = User.all
user  = users.first
following = users[2..50]
followers = users[3..40]
following.each { |followed| user.follow(followed) }
followers.each { |follower| follower.follow(user) }