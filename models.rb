require "sequel"
require "securerandom"
Sequel::Model.plugin :timestamps, update_on_create: true
class Order < Sequel::Model
  RE_ETH_ADDRESS = %r(^0x\h{40}$)
  unrestrict_primary_key
  def self.generate_id
    (SecureRandom.rand * 2**32).to_i
  end
end
