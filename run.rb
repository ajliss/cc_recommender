# frozen_string_literal: true

require 'pry'
require './calculator_v3'
require './calculator_v4'
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
      'Ineligible cards' => true,
      'Single Travel card' => true
    }
  end

  def self.required_cards
    {
      'A+' => false,
      'Altitude Reserve' => false,
      'Autograph' => false,
      'Bilt' => false,
      'VX' => false,
      'SO' => false
    }
  end

  def self.ineligible_subs
    {
      'Altitude Reserve' => true,
      'Altitude Go' => false,
      # 'BCE' => true,
      # 'BCP' => true,
      'CSP' => false,
      'CSR' => false,
      'SO' => false,
      'Amex Plat' => false,
      'Amex Gold' => false
    }
  end

  def self.ineligible_cards
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

  def self.run(combo_size)
    calulator = RewardsCalculatorV4.new(
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
