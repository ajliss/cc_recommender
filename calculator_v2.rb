# frozen_string_literal: true

require 'pry'
require 'json'

class RewardsCalculatorV2
  def initialize(opts)
    @flags = opts.fetch(:flags, {})
    @spending = opts.fetch(:spending, {})
    @reward_programs_points_values = opts.fetch(:reward_programs_points_values, {})
    @ineligible_cards = opts.fetch(:ineligible_cards, {})
    @ineligible_subs = opts.fetch(:ineligible_subs, {})
  end

  def run(combo_size)
    # combinations
    combos = get_cc_combinations(combo_size)
    # calculate
    reward_hashes = calculate_rewards(combos)
    # rank
    rankings = calculate_rankings(reward_hashes)
    # print result
    print(rankings)
  end

  def get_cc_combinations(size)
    cards = []
    combinations = []
    Dir.each_child('Cards') { |x| cards << JSON.parse(File.read(File.open(File.join(File.expand_path('./cards'), x)))) }
    cards.combination(size) { |pair| combinations << pair }
    unless @flags['AF']
      combinations.reject! do |combo|
        combo.any? { |c| c['Annual Fee'].positive? }
      end
    end
    combinations
  end

  def calculate_rewards(combos)
    combos.map do |cards|
      rewards = @spending.map do |cat, expenditure|
        multiplier = find_highest_value(cards, cat, expenditure)
        multiplier << expenditure
      end

      rewards_obj = build_rewards_object(cards, {})

      rewards.each do |arr|
        rewards_obj[arr[0]]['spending rewards'] += arr[1]
        rewards_obj['total']['spending rewards'] += arr[1]
      end

      combo_name = cards.sum('') { |el| "#{el['short name']}/" }.chomp('/')
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

  def find_highest_value(cards, category, expenditure)
    cards.map do |card|
      reward_multiplier = card[category].nil? ? card['Baseline'] : card[category]
      reward_program_multiplier = @reward_programs_points_values[card['Reward Program']]
      reward_program_multiplier *= card['Rewards Value Multiplier'] if card['Rewards Value Multiplier']
      credits = if @flags['Credits'] && card['Credits'][category]
                  card['Credits'][category].sum do |arr|
                    if arr[0] != 'General' && !@flags['Optional Credits']
                      0
                    else
                      arr[1]
                    end
                  end
                else
                  0
                end

      rewards = expenditure * reward_multiplier * reward_program_multiplier + credits
      [card['short name'], rewards]
    end.max { |a, b| a[1] <=> b[1] }
  end

  def build_rewards_object(cards, rewards_obj)
    cards.each_with_object(rewards_obj) do |card|
      name = card['short name']
      rewards_obj[name] = {}
      rewards_obj[name]['af'] = card['Annual Fee']
      rewards_obj[name]['Credits'] = card['Credits']['General']
      rewards_obj[name]['SUB'] = if @ineligible_subs[card['short name']]
                                   0
                                 else
                                   card['Sign up Bonus']['Value'] * @reward_programs_points_values[card['Reward Program']]
                                 end
      rewards_obj[name]['spending rewards'] = 0

      rewards_obj['total'] ||= {}
      rewards_obj['total']['af'] ||= 0
      rewards_obj['total']['af'] += card['Annual Fee']
      rewards_obj['total']['Credits'] ||= 0
      rewards_obj['total']['Credits'] += card['Credits']['General']
      rewards_obj['total']['SUB'] ||= 0
      unless @ineligible_subs[card['short name']]
        rewards_obj['total']['SUB'] += card['Sign up Bonus']['Value'] * @reward_programs_points_values[card['Reward Program']]
      end
      rewards_obj['total']['spending rewards'] = 0
    end
  end

  def calculate_all_rewards_values(years, rewards_obj, sub_flag = @flags['Sign up Bonus'])
    obj = {}
    rewards_obj.each_pair do |name, val|
      one_year_value = val['spending rewards']
      one_year_value -= val['af']
      one_year_value += val['Credits'] if @flags['Credits']

      obj[name] = {}
      obj[name]['total rewards'] = calculate_value(years, one_year_value, val['SUB'], sub_flag)
    end
    obj
  end

  def calculate_value(years, one_year_value, sub_value, sub_flag)
    value = years * one_year_value
    value += sub_value if sub_flag
    value.floor(2)
  end

  def calculate_rankings(reward_hashes)
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

  def build_rewards_report_line(obj, name)
    line = [obj['total']['total rewards'], name]
    contributions = []
    obj.each_pair do |key, val|
      next if key == 'total'

      contributions << [key, val['total rewards']]
    end
    contributions.sort! { |a, b| b.last <=> a.last }.flatten
    line + contributions
  end

  def print(rankings)
    print_set('One Year Ranking:', rankings['one_year_ranking'])
    print_set("\nThree Year Ranking:", rankings['three_year_ranking'])
    print_set("\nFive Year Ranking:", rankings['five_year_ranking'])
    print_set("\nTen Year Ranking:", rankings['ten_year_ranking'])
    print_set("\nThree Year Ranking, No SUBs:", rankings['three_year_ranking_no_subs'])
    print_set("\nTen Year Ranking, No SUBs:", rankings['ten_year_ranking_no_subs'])
  end

  def print_set(title, ranks)
    puts title
    10.times.each do |idx|
      break if ranks[idx].nil?

      puts ranks[idx].join(' - ')
    end
  end
end
