require 'rubygems'
require 'bundler/setup'
require 'nokogiri'
require 'json'
require 'csv'
require 'date'
require 'net/http'

API_URL = 'https://api.privatbank.ua/p24api/rest_fiz'

STATEMENT_FIELDS = {
  "card" => :card,
  "appcode" => :appcode,
  "date" => :trandate,
  "time" => :trantime,
  "amount" => :amount,
  "card amount" => :cardamount,
  "rest" => :rest,
  "terminal" => :termainal,
  "description" => :description
}

settings = JSON.load(File.read("settings.json"))

def to_compact_xml(xml_object)
  xml_object.to_xml(indent_text: '').gsub("\n", "")
end

# build request

start_date_str, end_date_str = [Date.today-31, Date.today].map{|d| d.strftime("%d.%m.%Y") }

request_builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
  xml.request {
    xml.merchant {
      xml.id_ settings["merchant_id"]
      xml.signature
    }
    xml.data {
      xml.oper "cmt"
      xml.wait 0
      xml.test 1
      xml.payment(id: '') {
        xml.prop(name: 'sd', value: start_date_str)
        xml.prop(name: 'ed', value: end_date_str)
        xml.prop(name: 'card', value: settings["card"])
      }
    }
  }
end

# sign
data_str = request_builder.doc.at_css('data').children.map{|c| to_compact_xml(c)}.join('')
signature = Digest::SHA1.hexdigest(Digest::MD5.hexdigest(data_str+settings['merchant_password']))
request_builder.doc.at_css('signature').content = signature

# send
uri = URI(API_URL)
response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
  request = Net::HTTP::Post.new uri
  request.body = to_compact_xml(request_builder)
  http.request request
end

xml = Nokogiri::XML(response.body)

if error =xml.at_css('error')
  puts error[:message]
else
  puts CSV.generate {|csv|
    csv << STATEMENT_FIELDS.keys
    xml.css('statement').each do |st|
      csv << STATEMENT_FIELDS.values.map{|key| st[key]}
    end
  }
end
