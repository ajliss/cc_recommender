# frozen_string_literal: true

require 'pry'
require './calculator_v3'
require './utils/spending'
require './utils/reward_programs_points_values'

class Run
  def self.flags
    {
      'AF' => true,
      'Cashback only' => false,
      'Credits' => true,
      'Sign up Bonus' => true,
      'SUB from normal spend' => false,
      'Required cards' => false,
      'Ineligible cards' => true
    }
  end

  def self.required_cards
    {
      'A+' => false,
      'Altitude Reserve' => false,
      'Autograph' => true,
      'Bilt' => true
    }
  end

  def self.ineligible_subs
    {
      'Altitude Reserve' => true,
      'Altitude Go' => true,
      'BCE' => true,
      'BCP' => true,
      'CSP' => true,
      'CSR' => true,
      'SO' => true
    }
  end

  def self.ineligible_cards
    {
      'Altitude Reserve' => false,
      'Altitude Go' => false,
      'BCE' => false,
      'SO' => true
    }
  end

  def self.run(combo_size)
    calulator = RewardsCalculatorV3.new(
      {
        flags:,
        spending: Utils::Spending.monthly,
        reward_programs_points_values: Utils::ProgramValues.values,
        ineligible_cards:,
        ineligible_subs:,
        required_cards:
      }
    )
    calulator.run(combo_size)
  end
end

Run.run(3)
