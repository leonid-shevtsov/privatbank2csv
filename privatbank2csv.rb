#!/usr/bin/env ruby

require 'rubygems'
require 'bundler/setup'
require 'roo'
require 'csv'

if ARGV.empty?
  puts "USAGE: privatbank2csv.rb statements.xls >statements.csv"
  exit 1
end

statements = Roo::Excel.new(ARGV[0]).sheet(0)

firstrow = true
transactions = statements.map do |row|
  if firstrow
    firstrow=false
    next
  end
  date, _card_number, memo, amount_card, currency_card, amount, currency, _balance = row

  date_parts = date.match(/(\d{2})\/(\d{2})\/(\d{4}) (\d{2}):(\d{2})/)
  date_obj = Time.mktime(date_parts[3], date_parts[2], date_parts[1], date_parts[4], date_parts[5])

  if currency_card != currency
    rate = (amount_card.to_f/amount.to_f).abs
    rate_and_memo = "(#{amount} #{currency}, rate=#{"%0.2f" % rate}) " + memo
  else
    rate_and_memo = memo
  end

  {
    date: date_obj,
    memo: memo,
    rate_and_memo: rate_and_memo,
    amount: amount_card
  }
end.compact.sort_by{|r| r[:date]}


puts CSV.generate {|csv|
  transactions.each_with_index do |t,i|
    csv << [t[:date].strftime("%Y-%m-%d %H:%I"), t[:memo], t[:rate_and_memo], t[:amount]]
  end
}
