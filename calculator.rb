require 'pry'
require 'json'

class RewardsCalculator
  def self.flags
    {
      'Credits' => true,
      'Sign up Bonus' => true,
      'AF' => true
    }
  end

  def self.reward_programs_points_values
    {
      'Amex MR' => 1.5,
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

  def self.spending
    {
      'Groceries' => 10 * 12,
      'Restaurants' => 200 * 12,
      'Streaming' => 25 * 12,
      'Gas' => 15 * 12,
      'Transit' => 10 * 12,
      'Phone' => 25 * 12,
      'Airfare' => 200 * 12,
      # 'Southwest' => 100 * 12,
      'Internet' => 60 * 12,
      'NBA Games' => 100 * 12,
      'Miscellaneous' => 300 * 12,
      # 'Amazon' => 200 * 12,
      'Apple Pay' => 85 * 12
    }
  end

  def self.run(combo_size)
    # combinations
    combos = get_cc_combinations(combo_size)
    # calculate
    reward_hashes = calculate_rewards(combos)
    # rank
    rankings = calculate_rankings(reward_hashes)
    # print result
    print(rankings)
  end

  def self.get_cc_combinations(size)
    cards = []
    combinations = []
    Dir.each_child('Cards') { |x| cards << JSON.parse(File.read(File.open(File.join(File.expand_path('./cards'), x)))) }
    cards.combination(size) { |pair| combinations << pair }
    combinations.reject! do |combo|
      combo.count { |c| c['Travel Card'] } > 1
    end
    unless flags['AF']
      combinations.reject! do |combo|
        combo.any? { |c| c['Annual Fee'].positive? }
      end
    end
    combinations
  end

  def self.calculate_rewards(combos)
    combos.map do |cards|
      rewards = []
      spending.each_pair do |key, value|
        multiplier = find_highest_multipler(cards, key)
        multiplier << value

        rewards << multiplier
      end

      rewards_obj = build_rewards_object(cards, {})

      rewards.each do |arr|
        rewards_obj[arr[0]]['spending rewards'] += arr[1] * arr[2]
        rewards_obj['total']['spending rewards'] += arr[1] * arr[2]
      end

      combo_name = cards.sum('') { |el| "#{el['short name']}/"}.chomp('/')
      {
        'name' => combo_name,
        'one year' => calculate_all_rewards_values(1, rewards_obj),
        'three years' => calculate_all_rewards_values(3, rewards_obj),
        'five years' => calculate_all_rewards_values(5, rewards_obj),
        'ten years' => calculate_all_rewards_values(10, rewards_obj),
        'three years no subs' => calculate_all_rewards_values(3, rewards_obj, false),
        'ten years no subs' => calculate_all_rewards_values(10, rewards_obj, false)
      }
    end
  end

  def self.build_rewards_object(cards, rewards_obj)
    cards.each_with_object(rewards_obj) do |card|
      name = card['short name']
      rewards_obj[name] ||= {}
      rewards_obj[name]['af'] = card['Annual Fee']
      rewards_obj[name]['Credits'] = card['Credits']
      rewards_obj[name]['SUB'] = card['Sign up Bonus'] * reward_programs_points_values[card['Reward Program']]
      rewards_obj[name]['spending rewards'] = 0

      rewards_obj['total'] ||= {}
      rewards_obj['total']['af'] ||= 0
      rewards_obj['total']['af'] += card['Annual Fee']
      rewards_obj['total']['Credits'] ||= 0
      rewards_obj['total']['Credits'] += card['Credits']
      rewards_obj['total']['SUB'] ||= 0
      rewards_obj['total']['SUB'] += card['Sign up Bonus'] * reward_programs_points_values[card['Reward Program']]
      rewards_obj['total']['spending rewards'] = 0
    end
  end

  def self.find_highest_multipler(cards, key)
    cards.map do |card|
      reward_multiplier = card[key].nil? ? card['Baseline'] : card[key]
      reward_program_multiplier = reward_programs_points_values[card['Reward Program']]
      reward_program_multiplier *= card['Rewards Value Multiplier'] if card['Rewards Value Multiplier']

      [card['short name'], reward_multiplier * reward_program_multiplier]
    end.sort { |a, b| b[1] <=> a[1] }.first
  end

  def self.calculate_all_rewards_values(years, rewards_obj, sub_flag = flags['Sign up Bonus'])
    obj = {}
    rewards_obj.each_pair do |name, val|
      one_year_value = val['spending rewards']
      one_year_value -= val['af']
      one_year_value += val['Credits'] if flags['Credits']

      obj[name] = {}
      obj[name]['total rewards'] = calculate_value(years, one_year_value, val['SUB'], sub_flag)
    end
    obj
  end

  def self.calculate_value(years, one_year_value, sub_value, sub_flag)
    value = years * one_year_value
    value += sub_value if sub_flag
    value.floor(2)
  end

  def self.calculate_rankings(reward_hashes)
    rankings = {
      'one_year_ranking' => [],
      'three_year_ranking' => [],
      'five_year_ranking' => [],
      'ten_year_ranking' => [],
      'three_year_ranking_no_subs' => [],
      'ten_year_ranking_no_subs' => []
    }

    reward_hashes.each do |combo|
      rankings['one_year_ranking'] << build_rewards_report_line(combo['one year'], combo['name']).flatten
      rankings['three_year_ranking'] << build_rewards_report_line(combo['three years'], combo['name']).flatten
      rankings['five_year_ranking'] << build_rewards_report_line(combo['five years'], combo['name']).flatten
      rankings['ten_year_ranking'] << build_rewards_report_line(combo['ten years'], combo['name']).flatten
      rankings['three_year_ranking_no_subs'] << build_rewards_report_line(combo['three years no subs'], combo['name']).flatten
      rankings['ten_year_ranking_no_subs'] << build_rewards_report_line(combo['ten years no subs'], combo['name']).flatten
    end

    rankings.each_value do |val|
      val.sort! { |a, b| b.first <=> a.first }
    end
    rankings
  end

  def self.build_rewards_report_line(obj, name)
    line = [obj['total']['total rewards'], name]
    contributions = []
    obj.each_pair do |key, val|
      next if key == 'total'

      contributions << [key, val['total rewards']]
    end
    contributions.sort! { |a, b| b.last <=> a.last }.flatten
    line + contributions
  end

  def self.print(rankings)
    print_set('One Year Ranking:', rankings['one_year_ranking'])
    print_set("\nThree Year Ranking:", rankings['three_year_ranking'])
    print_set("\nFive Year Ranking:", rankings['five_year_ranking'])
    print_set("\nTen Year Ranking:", rankings['ten_year_ranking'])
    print_set("\nThree Year Ranking, No SUBs:", rankings['three_year_ranking_no_subs'])
    print_set("\nTen Year Ranking, No SUBs:", rankings['ten_year_ranking_no_subs'])
  end

  def self.print_set(title, ranks)
    puts title
    10.times.each do |idx|
      break if ranks[idx].nil?

      puts ranks[idx].join(' - ')
    end
  end
end

RewardsCalculator.run(4)
