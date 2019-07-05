Sequel.migration do
  up do
    create_table(:orders) do
      String :id, primary_key: true
      BigDecimal :amount, size: [16,8] # up to 99999999.99999999

      # we will store this data after we ask 0xBTCpay to start a payment
      String :address, index: true, unique: true
      String :payment_id, index: true, unique: true

      # we will send this to 0xBTCpay and check it when it comes back to ensure
      # we're talking to 0xBTCpay and not anyone else
      String :postback_secret

      # we will store this after 0xBTCpay gives us a postback (when order has
      # been paid)
      String :tx_hash, index: true
      Time :paid_at

      Time :created_at, index: true
      Time :updated_at
    end
  end
  down do
    drop_table :orders
  end
end
