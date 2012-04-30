# Be sure to restart your server when you modify this file.

# Your secret key for verifying cookie session data integrity.
# If you change this key, all old sessions will become invalid!
# Make sure the secret is at least 30 characters and all random, 
# no regular words or you'll be exposed to dictionary attacks.
ActionController::Base.session = {
  :key         => '_CAPI_session',
  :secret      => 'd0df49effd41c7290a4a7d9f9a0ab230f48826d418c35a40be289b4a9138385424d9a2872ae27122d8fc1ecab8b51e7e0469f324eb660731f4cd01cf6afd27c7'
}

# Use the database for sessions instead of the cookie-based default,
# which shouldn't be used to store highly confidential information
# (create the session table with "rake db:sessions:create")
# ActionController::Base.session_store = :active_record_store
