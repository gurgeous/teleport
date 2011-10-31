module Constants
  # The temp directory that teleport uses on the target machine.
  DIR = "/tmp/_teleported"
  
  # The teleport gem within our temp directory.
  GEM = "#{DIR}/gem"
  
  # Directory where user install data (Telfile and friends) is stored.
  DATA = "#{DIR}/data"
  
  # Directory where user install files are stored.
  FILES = "#{DIR}/data/files"
  
  # Name of the public key to install on the target machine.
  PUBKEY = "id_teleport.pub"

  # Minimum version of rubygems to install.
  RUBYGEMS = "1.8.10"
end
