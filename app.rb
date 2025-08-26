# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'sinatra/cookies'
require './utils/spending'
require './calculator_v4_web'
require './utils/reward_programs_points_values'
require './utils/options'

use Rack::Session::Pool
configure :development do
  register Sinatra::Reloader
end

get '/' do
  use_or_set_spending
  use_or_set_points_values
  use_or_set_flags
  session_rewards = JSON.parse(session['rewards'].gsub(/=>/, ':')) if session['rewards']
  flags = JSON.parse(session['flags'].gsub(/=>/, ':'))
  last_run_cards_no = session['last_run_cards_no'] || 1

  erb :index, locals: {
    results: session_rewards,
    last_run_cards_no:,
    cashback_only: flags['Cashback only'],
    upgradeable_points: flags['Upgradeable points']
  }
end

get '/calculate_rewards' do
  use_or_set_spending
  use_or_set_points_values
  use_or_set_card_options
  use_or_set_flags

  # if session.dig('calculated', params['no_of_cards'], session['spending_hash'])
  #   rewards = session.dig('calculated', params['no_of_cards'], session['points_value_hash'], session['spending_hash'])
  # else
  optioned_cards = find_optioned_cards
  save_flags(params)

  rewards = calculate(params['no_of_cards'].to_i, optioned_cards).to_s
  add_to_hash(['calculated', params['no_of_cards'], session['points_value_hash'], session['spending_hash']], session, rewards)
  # end
  session['last_run_cards_no'] = params['no_of_cards'].to_i
  session['rewards'] = rewards
  redirect '/'
end

get '/card_options' do
  use_or_set_card_options
  session_card_options = JSON.parse(session['card_options'].gsub(/=>/, ':'))
  erb :card_options, locals: { card_options: session_card_options }
end

get '/reset_settings' do
  session['spending'] = default_spending
  session['points_values'] = default_points_values
  session['card_options'] = default_card_options
  session['flags'] = default_flags.to_s

  redirect back
end

get '/points_values' do
  # spending
  use_or_set_points_values
  session_points_values = JSON.parse(session['points_values'].gsub(/=>/, ':'))
  erb :points_values, locals: { points_values: session_points_values }
end

get '/spending_profile' do
  # spending
  use_or_set_spending
  session_spending = JSON.parse(session['spending'].gsub(/=>/, ':'))
  erb :spending, locals: { spending: session_spending }
end

post '/save_card_options' do
  # save to session
  card_options = JSON.parse(default_card_options.gsub(/=>/, ':'))
  updated_card_options = update_hash(params, card_options)
  session['card_options'] = updated_card_options.to_s
  session['card_options_hash'] = session['card_options'].hash

  redirect '/card_options'
end

post '/save_points_values' do
  # save to session
  points_values = session['points_values'] || default_points_values
  points_values = JSON.parse(points_values.gsub(/=>/, ':'))
  updated_points_values = update_hash(params, points_values)
  session['points_values'] = updated_points_values.to_s
  session['points_values_hash'] = session['points_values'].hash

  redirect '/points_values'
end

post '/save_spending' do
  # save to session
  spending = session['spending'] || default_spending
  spending = JSON.parse(spending.gsub(/=>/, ':'))
  updated_spending = update_hash(params, spending)
  session['spending'] = updated_spending.to_s
  session['spending_hash'] = session['spending'].hash

  redirect '/spending_profile'
end

def use_or_set_card_options
  session['card_options'] = default_card_options unless session['card_options']
  session['card_options_hash'] = session['card_options'].hash
end

def default_card_options
  Utils::Options.card_options.to_s
end

def find_optioned_cards
  obj = {
    required: {},
    excluded: {},
    no_sub: {}
  }

  JSON.parse(session['card_options'].gsub(/=>/, ':')).each_pair do |key, val|
    next if val.empty?

    val.each_key do |k|
      case k
      when 'required'
        obj[:required][key] = true
      when 'excluded'
        obj[:excluded][key] = true
      when 'no-sub'
        obj[:no_sub][key] = true
      end
    end
  end
  obj
end

def save_flags(params)
  flags = default_flags
  flags['Cashback only'] = true if params['cashback_only']
  flags['Upgradeable points'] = true if params['upgradeable_points']
  session['flags'] = flags.to_s
  session['flags_hash'] = session['flags'].hash
end

def use_or_set_flags
  session['flags'] = default_flags.to_s unless session['flags']
  session['flags_hash'] = session['flags'].hash
end

def default_flags
  {
    'AF' => true,
    'Cashback only' => false,
    'Single Travel card' => true,
    'Upgradeable points' => false
  }
end

def use_or_set_points_values
  session['points_values'] = default_points_values unless session['points_values']
  session['points_values_hash'] = session['points_values'].hash
end

def default_points_values
  Utils::ProgramValues.values.to_s
end

def use_or_set_spending
  session['spending'] = default_spending unless session['spending']
  session['spending_hash'] = session['spending'].hash
end

def default_spending
  Utils::Spending.monthly.to_s
end

def update_hash(params, old_hash)
  params.each_pair do |key, val|
    keys = key.split('_')
    next if old_hash.dig(*keys) == val

    keys[0...-1].inject(old_hash, :fetch)[keys.last] = val.to_s
  end
  old_hash
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

def calculate(combo_size, optioned_cards)
  calulator = RewardsCalculatorV4Web.new(
    {
      flags: JSON.parse(session['flags'].gsub(/=>/, ':')),
      spending: JSON.parse(session['spending'].gsub(/=>/, ':')),
      reward_programs_points_values: JSON.parse(session['points_values'].gsub(/=>/, ':')),
      excluded_cards: optioned_cards[:excluded],
      ineligible_subs: optioned_cards[:no_sub],
      required_cards: optioned_cards[:required]
    }
  )
  calulator.run(combo_size)
end
