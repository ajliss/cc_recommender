# frozen_string_literal: true

module Utils
  class Spending
    def self.monthly
      {
        'Dining' => {
          'Restaurant' => 0,
          'Doordash' => 0,
          'Grubhub' => 0,
          'UberEats' => 0
        },
        'Drugstores' => 0,
        'Gas' => 0,
        'Groceries' => {
          'General' => 0,
          'Apple Pay' => 0
        },
        'Entertainment' => 0,
        'Miscellaneous' => {
          'Apple Pay' => 0,
          'General' => 0
        },
        'Online Shopping' => {
          'Amazon.com' => 0,
          'Walmart.com' => 0,
          'Online Retail' => 0,
          'Groceries.com' => 0,
          'Target' => 0
        },
        'Streaming' => {
          'Disney' => 0,
          'Netflix' => 0,
          'Spotify' => 0,
          'Apple TV' => 0
        },
        'Travel' => {
          'Airlines' => {
            # TODO: Add individual airlines
            'Generic' => {
              'General' => 0,
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
          'Airbnb' => 0,
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
            'Lyft' => 0,
            'Uber' => 0
          },
          'Transit' => 0
        },
        'Utilities' => {
          'Phone' => 0,
          'Internet' => 0,
          'Cable' => 0,
          'General' => 0,
          'Apple Pay' => 0
        }
      }
    end
  end
end
