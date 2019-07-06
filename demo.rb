require "haml"
require "httparty"
require "sinatra"
require "securerandom"
require "./db"

set(:port, 8000)

get "/" do
  @shirts = rand(3) + 1
  @price = 0.001
  @total = @price * @shirts
  haml :index
end

post "/" do
  @total = BigDecimal(params[:total])
  order = Order.new
  order.id = Order.generate_id
  order.amount = @total
  # make a secret password for 0xBTCpay to give us with the postback, after
  # payment has been made, so we can be sure we're really talking to our
  # 0xBTCpay and not anyone else.
  order.postback_secret = SecureRandom.hex(8)

  # ask 0xBTCpay to start a payment
  headers = {"Content-Type" => "application/json"}
  body = {
    method: "start_payment",
    params: {
      amount: @total.to_s("F"),
      # 0xBTCpay will give us this data in the postback, after the customer has
      # paid the full amount of 0xBitcoin.
      data: {order_id: order.id, postback_secret: order.postback_secret},
      # 0xBTCpay will do a POST to our postback_url when the payment is complete.
      postback_url: "https://demo.0xbtcpay.io/postback"
    },
    id:1, # this is not an order ID. it can always be 1 (or whatever). part of JSONRPC.
    jsonrpc:"2.0"
  }.to_json
  r = HTTParty.post("https://payments.0xbtcpay.io", body: body, headers: headers)

  # 0xBTCpay will give us back data like this:
  # {
  #   id: "2e33e3beb7ec2af9",    # ID for tracking the payment with 0xBTCpay
  #   amount: "0.001",           # same as our order.amount
  #   address: "0xabcdef..."     # ethereum address the customer should send 0xBTC to
  # }
  result = r.parsed_response["result"]

  halt 500 unless result

  # update our order with these details
  order.payment_id = result["id"]
  order.address = r["address"]
  order.save

  redirect "/#{order.id}"
end

# order lookup page
get %r(/(\d+)) do
  order_id = params["captures"].first
  @order = Order[order_id]
  halt 404, "order not found" unless @order

  if !@order.paid_at
    haml :payment
  else
    # allow access to spicy memes
    get_memes
    haml :order
  end
end

# our postback. 0xBTCpay will call this when payment is complete.
# the JSON data will look like this:
# {
#   id: "2e33e3beb7ec2af9",  # ID for tracking the payment with 0xBTCpay
#   data: {...},             # our original data that we sent 0xBTCpay
#   tx_hash: "0xeff223.."    # the ethereum transaction of the payment
# }
post "/postback" do
  postback = JSON.parse(request.body.read, symbolize_names: true)

  # this is our original data that we sent 0xBTCpay
  data = JSON.parse(postback[:data], symbolize_names: true)

  # look up the order 0xBTCpay is telling us about
  order_id = data[:order_id]

  order = Order[order_id]
  halt 500 unless order

  # make sure we are really talking to 0xBTCpay, not an imposter
  if order.postback_secret != data[:postback_secret]
    halt 403, "forbidden!"
  end

  # okay, the order is really paid
  order.paid_at = Time.now
  order.tx_hash = postback[:tx_hash]
  order.save

  halt 200, "thanks, 0xBTCpay"
end

### helpers

def get_memes
  $meme_files ||= Dir.entries("public/memes").grep(%r((.png|.gif|.jpg)$)i)
  num_memes = (@order.amount / 0.001).to_i
  @memes = []
  srand @order.id.to_i
  random_memes = $meme_files.shuffle
  num_memes.times do
    @memes << random_memes.pop
  end
end
