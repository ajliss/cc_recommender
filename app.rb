# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require './utils/spending'
require './calculator_v4_web'
require './utils/reward_programs_points_values'
require 'pry'

configure :development do
  register Sinatra::Reloader
end

def default_spending
  Utils::Spending.monthly.to_s
end

def use_or_update_spending
  session['spending'] = default_spending unless session['spending']
  session['spending_hash'] = session['spending'].hash
end

use Rack::Session::Pool
get '/' do
  use_or_update_spending
  session_rewards = JSON.parse(session['rewards'].gsub(/=>/, ':')) if session['rewards']
  erb :index, locals: { results: session_rewards }
end

get '/spending_profile' do
  # spending
  use_or_update_spending
  cookie_spending = JSON.parse(session['spending'].gsub(/=>/, ':'))
  erb :spending, locals: { spending: cookie_spending }
end

get '/calculate_rewards' do
  use_or_update_spending
  if session.dig('calculated', params['no_of_cards'], session['spending_hash'])
    rewards = session.dig('calculated', params['no_of_cards'], session['spending_hash'])
  else
    session_spending = JSON.parse(session['spending'].gsub(/=>/, ':'))
    rewards = calculate(params['no_of_cards'].to_i, session_spending).to_s
    add_to_hash(['calculated', params['no_of_cards'], session['spending_hash']], session, rewards)
  end
  session['rewards'] = rewards
  redirect '/'
end

post '/save_spending' do
  # save cookies
  save_spending(params)
  redirect '/spending_profile'
end

def save_spending(params)
  spending = session['spending'] || default_spending
  spending = JSON.parse(spending.gsub(/=>/, ':'))
  params.each_pair do |key, val|
    keys = key.split('_')
    next if spending.dig(*keys) == val

    keys[0...-1].inject(spending, :fetch)[keys.last] = val.to_i
  end
  session['spending'] = spending.to_s
  session['spending_hash'] = session['spending'].hash
end

def add_to_hash(key_array, hash, rewards)
  key = key_array.shift
  if key_array.empty?
    hash[key] = rewards
  else
    hash[key] ||= {}
    add_to_hash(key_array, hash[key], rewards)
  end
end

def flags
  {
    'AF' => true,
    'Cashback only' => false,
    'Credits' => true,
    # 'Sign up Bonus' => true,
    'SUB from normal spend' => false,
    'Required cards' => false,
    'Ineligible cards' => true,
    'Single Travel card' => true,
    'Upgradeable points' => true
  }
end

def required_cards
  {
    'A+' => false,
    'Altitude Reserve' => false,
    'Autograph' => false,
    'Bilt' => false,
    'Amex Business Plat' => false,
    'VX' => false,
    'SO' => false
  }
end

def ineligible_subs
  {
    'Altitude Reserve' => true,
    'Altitude Go' => false,
    # 'BCE' => true,
    # 'BCP' => true,
    'CSP' => false,
    'CSR' => false,
    'SO' => false,
    'Amex Plat' => false,
    'Amex Business Plat' => true,
    'Amex Gold' => false
  }
end

def ineligible_cards
  {
    # 'A+' => true,
    'Altitude Reserve' => true,
    'Altitude Go' => false,
    'BCE' => false,
    'Bilt' => true,
    'SO' => false,
    'Amex Plat' => false,
    'Amex Gold' => false
  }
end

def calculate(combo_size, spending_hash)
  calulator = RewardsCalculatorV4Web.new(
    {
      flags:,
      spending: spending_hash,
      reward_programs_points_values: Utils::ProgramValues.values,
      ineligible_cards:,
      ineligible_subs:,
      required_cards:
    }
  )
  calulator.run(combo_size)
end
