module Utils
  class Spending
    def self.monthly
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
  end
end
