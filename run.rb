require 'pry'
require 'json'
require './calculator_v2'
require './calculator_v3'

class Run
  def self.flags
    {
      'AF' => true,
      'Cashback only' => false,
      'Credits' => true,
      # 'Optional Credits' => false,
      'Sign up Bonus' => true,
      'SUB from normal spend' => false
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

  def self.spending
    {
      'Groceries' => 15 * 12,
      'Restaurants' => 200 * 12,
      'Streaming' => 22 * 12,
      'Gas' => 15 * 12,
      'Transit' => 10 * 12,
      'Phone' => 25 * 12,
      'Airfare' => 350 * 12,
      'Southwest' => 100 * 12,
      'Internet' => 60 * 12,
      'NBA Games' => 120 * 12,
      'Miscellaneous' => 440 * 12,
      # 'Amazon' => 200 * 12,
      'Apple Pay' => 78 * 12
    }
  end

  def self.spending_v2
    {
      'Dining' => {
        'Restaurant' => 120,
        'Doordash' => 0,
        'Grubhub' => 0,
        'UberEats' => 0
      },
      'Drugstores' => 0,
      'Gas' => 15,
      'Groceries' => 10,
      'Miscellaneous' => {
        'Apple Pay' => 150,
        'General' => 230
      },
      'Online Shopping' => {
        'Amazon.com' => 15,
        'Walmart.com' => 0,
        'Online Retail' => 10,
        'Groceries.com' => 0,
        'Target' => 0
      },
      'Streaming' => {
        'Disney/Hulu Bundle' => 0,
        'Netflix' => 22
      },
      'Travel' => {
        'Airlines' => {
          # TODO: Add individual airlines
          'Generic' => {
            'General' => 200,
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0,
              'General' => 0
            }
          },
          'Portal' => {
            'General' => 0,
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0,
              'General' => 0
            }
          },
          'American Airlines' => {
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0
            }
          },
          'Delta' => {
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0
            }
          },
          'Southwest' => {
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0
            }
          },
          'United Airlines' => {
            'Tickets' => 0,
            'Incidentals' => {
              'Bags' => 0,
              'Upgrades' => 0
            }
          }
        },
        'Airbnb' => 20,
        'Car Rentals' => 0,
        'Hotels' => {
          'General' => 0,
          'Portal' => 0,
          'Best Western' => 0,
          'Choice Privileges' => 0,
          'Hilton Honors' => 0,
          'Hyatt' => 0,
          'IHG Rewards Club' => 0,
          'Marriott Rewards' => 0,
          'Radisson rewards' => 0,
          'Wyndham Rewards' => 0
        },
        'Ride Share' => {
          'Lyft' => 5,
          'Uber' => 0
        },
        'Transit' => 10
      },
      'Utilities' => {
        'Phone' => 25,
        'Internet' => 60,
        'Cable' => 0,
        'General' => 0
      }
    }
  end

  def self.reward_programs_points_values
    # from frequent miler
    {
      'Amex MR' => 1.55,
      'Bilt' => 1.55,
      'American AAdvantage' => 1.3,
      'BOA Rewards' => 1,
      'Capital One Venture' => 1.4,
      'Cashback' => 1,
      'Chase UR' => 1.5,
      'Citi TY' => 1.4,
      'Delta Skymiles' => 1.2,
      'Hilton Honors' => 0.5,
      'Marriott Bonvoy' => 0.8,
      'Penfed' => 0.85,
      'Southwest' => 1.4,
      'United' => 1.3,
      'US Bank' => 1,
      'US Bank Reserve' => 1.5
    }
  end

  def self.reward_programs_points_values_v2
    # from frequent miler
    {
      'Transferable' => {
        'American Express Membership Rewards' => {
          'Airline Partners' => {
            'Aer Lingus AerClub' => 0,
            'Aero Mexico Club Premier' => 0 * 1.6,
            'Air Canada AeroPlan' => 1.3,
            'Air France/KLM Flying Blue Miles' => 0,
            'Avianca LifeMiles' => 1.3,
            'British Airways Avios' => 1.09,
            'Cathay Pacific Asia Miles' => 1.09,
            'Delta Skymiles' => 1.3,
            'Emirates Skywards Miles' => 0,
            'Hawaiian Airlines HawaiianMiles' => 0.75,
            'Iberia Avios' => 0,
            'JetBlue TrueBlue' => 1.33 * 0.8,
            'Qantas Frequent Flyer' => 0,
            'Singapore Airlines KrisFlyer' => 0,
            'Virgin Atlantic Flying Club' => 1.3
          },
          'Generic Value' => 1.55,
          'Cashback' => 0.6,
          'Hotel Partners' => {
            'Choice Privileges' => 0.68,
            'Hilton Honors' => 0.48 * 2,
            'Marriott Rewards' => 0.8
          },
          'Schwab' => 1.1
        },
        'Bilt' => {
          'Airline Partners' => {
            'Aer Lingus AerClub' => 0,
            'Air Canada AeroPlan' => 1.3,
            'Air France/KLM Flying Blue Miles' => 0,
            'American AAdvantage' => 1.3,
            'British Airways Avios' => 1.09,
            'Cathay Pacific Asia Miles' => 1.09,
            'Emirates Skywards Miles' => 0,
            'Etihad Guest' => 0,
            'Hawaiian Airlines HawaiianMiles' => 0.75,
            'Iberia Avios' => 0,
            'Turkish Airlines Miles and Smiles' => 0,
            'United MileagePlus' => 1.3,
            'Virgin Atlantic Flying Club' => 1.3
          },
          'Generic Value' => 1.55,
          'Cashback' => 0.55,
          'Hotel Partners' => {
            'Hyatt' => 2.1,
            'IHG Rewards Club' => 0.63
          }
        },
        'Capital One Miles' => {
          'Airline Partners' => {
            'Aero Mexico Club Premier' => 0,
            'Air Canada AeroPlan' => 1.3,
            'Air France/KLM Flying Blue Miles' => 0,
            'Accor Live Limitless' => 0 * 0.5,
            'Avianca LifeMiles' => 1.3,
            'British Airways Avios' => 1.09,
            'Cathay Pacific Asia Miles' => 1.09,
            'Emirates Skywards Miles' => 0,
            'Etihad Guest' => 0,
            'EVA Air Infinity MileageLands' => 0 * 0.75,
            'Finnair Plus' => 0,
            'Qantas Frequent Flyer' => 0,
            'Singapore Airlines KrisFlyer' => 0,
            'TAP Portugal Miles and Go' => 0,
            'Turkish Airlines Miles and Smiles' => 0,
            'Virgin Atlantic Flying Club' => 1.3
          },
          'Generic Value' => 1.45,
          'Cashback' => 0.7,
          'Hotel Partners' => {
            'Choice Privileges' => 0.68,
            'Wyndham Rewards' => 0.88
          }
        },
        'Chase Ultimate Rewards' => {
          'Airline Partners' => {
            'Aer Lingus AerClub' => 0,
            'Air Canada AeroPlan' => 1.3,
            'Air France/KLM Flying Blue Miles' => 0,
            'British Airways Avios' => 1.09,
            'Emirates Skywards Miles' => 0,
            'Iberia Avios' => 0,
            'JetBlue TrueBlue' => 1.33,
            'Singapore Airlines KrisFlyer' => 0,
            'Southwest Rapid Rewards' => 1.4,
            'United MileagePlus' => 1.3,
            'Virgin Atlantic Flying Club' => 1.3
          },
          'Generic Value' => 1.5,
          'Cashback' => 1,
          'Hotel Partners' => {
            'Hyatt' => 2.1,
            'IHG Rewards Club' => 0.63,
            'Marriott Rewards' => 0.8
          }
        },
        'Citi ThankYou Rewards' => {
          'Airline Partners' => {
            'Aeromexico' => 0,
            'Accor Live Limitless' => 0 * 0.5,
            'Avianca Lifemiles' => 0,
            'Emirates Skywards Miles' => 0,
            'Etihad Guest' => 0,
            'EVA Air' => 0,
            'Air France/KLM Flying Blue Miles' => 0 * 1.25,
            'JetBlue TrueBlue' => 0,
            'Qantas Frequent Flyer' => 0,
            'Qatar Privilege Club' => 0,
            'Singapore Airlines KrisFlyer' => 0,
            'Thai Royal Orchid Plus' => 0,
            'Turkish Airlines Miles and Smiles' => 0,
            'Virgin Atlantic Flying Club' => 0
          },
          'Generic Value' => 1.45,
          'Cashback' => 1,
          'Hotel Partners' => {
            'Wyndham Rewards' => 0,
            'Choice Privileges' => 0 * 1.2
          }
        }
      },
      'Airlines' => {
        'Air Canada AeroPlan' => 1.3,
        'Alaska MileagePlan' => 1.3,
        'American AAdvantage' => 1.3,
        'Avianca LifeMiles' => 1.3,
        'British Airways Avios' => 1.09,
        'Cathay Pacific Asia Miles' => 1.09,
        'Delta Skymiles' => 1.3,
        'Delta Skymiles Cardholder' => 1.5,
        'Frontier Bonus Miles' => 0.95,
        'Hawaiian Miles' => 0.75,
        'JetBlue TrueBlue' => 1.33,
        'Korean SkyPass' => 1.3,
        'LATAM Pass' => 0.62,
        'Lufthansa Miles' => 1.3,
        'Southwest Rapid Rewards' => 1.4,
        'United MileagePlus' => 1.3,
        'Virgin Atlantic Flying Club' => 1.3
      },
      'Hotels' => {
        'Best Western' => 0.54,
        'Choice Privileges' => 0.68,
        'Hilton Honors' => 0.48,
        'Hyatt' => 2.1,
        'IHG Rewards Club' => 0.63,
        'Marriott Rewards' => 0.8,
        'Radisson rewards' => 0.34,
        'Wyndham Rewards' => 0.88
      },
      'Nontransferable' => {
        'BOA Rewards' => 1,
        'Cashback' => 1,
        'Penfed' => 0.85,
        'US Bank' => 1,
        'US Bank Reserve' => 1.5
      },
    }
  end

  def self.run(combo_size)
    calulator = RewardsCalculatorV3.new(
      {
        flags:,
        spending: spending_v2,
        reward_programs_points_values: reward_programs_points_values_v2,
        ineligible_cards:,
        ineligible_subs:
      }
    )
    calulator.run(combo_size)
  end
end

Run.run(3)
