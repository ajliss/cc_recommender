# frozen_string_literal: true

require 'pry'
require 'json'

class RewardsCalculatorV3
  def initialize(opts)
    @flags = opts.fetch(:flags, {})
    @spending = opts.fetch(:spending, {})
    @reward_programs_points_values = opts.fetch(:reward_programs_points_values, {})
    @ineligible_cards = opts.fetch(:ineligible_cards, {})
    @ineligible_subs = opts.fetch(:ineligible_subs, {})
    @required_cards = opts.fetch(:required_cards, {})
  end

  def run(combo_size)
    time = Time.now
    # combinations
    combos = get_cc_combinations(combo_size)
    # calculate
    reward_hashes = calculate_rewards(combos)
    # rank
    rankings = calculate_rankings(reward_hashes)

    spending_total = sum_spending
    # print result
    print(rankings, spending_total, time)
  end

  def get_cc_combinations(size)
    cards = []
    combinations = []
    Dir.each_child('Cards') do |x|
      card = JSON.parse(File.read(File.open(File.join(File.expand_path('./cards'), x))))

      next if @flags['Ineligible cards'] && @ineligible_cards[card['short name']]
      next if !@flags['AF'] && card['Annual Fee'].positive?

      card_rewards_hash = {}
      building_spending_profile(card, card_rewards_hash, card['Credits'], @spending, [])
      card['spending'] = card_rewards_hash
      cards << card
    end
    cards.combination(size) { |pair| combinations << pair }
    filter_combinations(combinations)
  end

  def filter_combinations(combinations)
    combinations = filter_by_required_cards(combinations)
    combinations = filter_by_travel_cards(combinations)
    combinations
  end

  def filter_by_required_cards(combinations)
    return combinations unless @flags['Required cards']

    combinations.filter do |combo|
      required_card_names = @required_cards.each_pair.map { |a| a[0] if a[1] }.compact
      combo_names = combo.map { |c| c['short name'] }
      (required_card_names - combo_names).empty?
    end
  end

  def filter_by_travel_cards(combinations)
    return combinations unless @flags['Single Travel card']

    combinations.filter do |combo|
      combo.count { |card| card['Travel Card'] } < 2
    end
  end

  def building_spending_profile(card, card_rewards_hash, credits_hash, spending_hash, keys)
    credits_hash ||= {}
    spending_hash.each_key do |key|
      keys << key
      if spending_hash[key].instance_of?(::Hash)
        # dig deeper
        card_rewards_hash[key] ||= {}
        building_spending_profile(card, card_rewards_hash[key], credits_hash[key], spending_hash[key], keys)
      else
        spending = spending_hash[key] * 12
        multiplier = card.dig(*keys) || card['Baseline']
        rewards = spending * multiplier
        credits = credits_hash[key]&.first || 0
        credits = spending if credits > spending

        card_rewards_hash[key] = [rewards, credits] unless spending_hash[key].zero?
      end
      keys.pop
    end
  end

  def calculate_rewards(combos)
    combos.map do |cards|
      rewards_obj = build_rewards_object(cards)
      keys = cards.first['spending'].keys

      until keys.empty?
        if cards.first['spending'].dig(*keys.first).instance_of?(::Hash)
          cards.first['spending'].dig(*keys.first).each_key do |k|
            keys << [keys.first, k].flatten
          end
        else
          add_rewards_value_to_object(cards, keys.first, rewards_obj)
        end

        keys.shift
      end

      all_rewards_value_object(cards, rewards_obj)
    end
  end

  def add_rewards_value_to_object(cards, key, rewards_obj)
    rewards_values = cards.map do |card|
      [card['short name'], category_value(card, key)]
    end.max { |a, b| a[1] <=> b[1] }

    rewards_obj[rewards_values[0]]['spending rewards'] += rewards_values[1]
    rewards_obj['total']['spending rewards'] += rewards_values[1]
  end

  def category_value(card, key)
    rewards_arr = card['spending'].dig(*key)

    # return rewards_arr.sum if @flags['Cashback only']

    case card['Program Type']
    when 'Nontransferable'
      rewards_arr[0] * @reward_programs_points_values['Nontransferable'][card['Reward Program']] + rewards_arr[1]
    when 'Transferable'
      if @flags['Cashback only']
        rewards_arr[0] * @reward_programs_points_values['Transferable'][card['Reward Program']]['Cashback'] + rewards_arr[1]
      else
        rewards_arr[0] * @reward_programs_points_values['Transferable'][card['Reward Program']]['Generic Value'] + rewards_arr[1]
      end
    when 'Airlines'
      if @flags['Cashback only']
        rewards_arr.sum
      else
        rewards_arr[0] * @reward_programs_points_values['Airlines'][card['Reward Program']] + rewards_arr[1]
      end
    when 'Hotels'
      if @flags['Cashback only']
        rewards_arr.sum
      else
        rewards_arr[0] * @reward_programs_points_values['Hotels'][card['Reward Program']] + rewards_arr[1]
      end
    end
  end

  def all_rewards_value_object(cards, rewards_obj)
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

  def build_rewards_object(cards)
    cards.each_with_object({}) do |card, rewards_obj|
      name = card['short name']
      rewards_obj[name] = {}
      rewards_obj[name]['af'] = card['Annual Fee']
      rewards_obj[name]['Credits'] = card.dig('Credits','General').nil? ? 0 : card['Credits']['General'].first
      rewards_obj[name]['SUB'] = find_sub_value(card)
      rewards_obj[name]['spending rewards'] = 0

      rewards_obj['total'] ||= {}
      rewards_obj['total']['af'] ||= 0
      rewards_obj['total']['af'] += card['Annual Fee']
      rewards_obj['total']['Credits'] ||= 0
      rewards_obj['total']['Credits'] += card.dig('Credits','General').nil? ? 0 : card['Credits']['General'].first
      rewards_obj['total']['SUB'] ||= 0
      rewards_obj['total']['SUB'] += rewards_obj[name]['SUB'] unless @ineligible_subs[card['short name']]
      rewards_obj['total']['spending rewards'] = 0
    end
  end

  def find_sub_value(card)
    return 0 if @ineligible_subs[card['short name']]

    sub =  card['Sign up Bonus']['Points Value']
    return sub if @flags['Cashback only']

    case card['Program Type']
    when 'Nontransferable'
      sub * @reward_programs_points_values['Nontransferable'][card['Reward Program']] + card['Sign up Bonus']['Cash Value']
    when 'Transferable'
      sub * @reward_programs_points_values['Transferable'][card['Reward Program']]['Generic Value'] + card['Sign up Bonus']['Cash Value']
    when 'Airlines'
      sub * @reward_programs_points_values['Airlines'][card['Reward Program']] + card['Sign up Bonus']['Cash Value']
    when 'Hotels'
      sub * @reward_programs_points_values['Hotels'][card['Reward Program']] + card['Sign up Bonus']['Cash Value']
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

  def sum_spending
    arr = []
    @spending.each_value do |val|
      if val.instance_of?(::Hash)
        find_ints(val, arr)
      else
        arr << val
      end
    end
    arr.sum * 12
  end

  def find_ints(obj, arr)
    obj.each_value do |val|
      if val.instance_of?(::Hash)
        find_ints(val, arr)
      else
        arr << val
      end
    end
  end

  def print(rankings, spending_total, time)
    print_set('One Year Ranking:', rankings['one_year_ranking'], spending_total, 1)
    print_set("\nThree Year Ranking:", rankings['three_year_ranking'], spending_total, 3)
    print_set("\nFive Year Ranking:", rankings['five_year_ranking'], spending_total, 5)
    print_set("\nTen Year Ranking:", rankings['ten_year_ranking'], spending_total, 10)
    print_set("\nThree Year Ranking, No SUBs:", rankings['three_year_ranking_no_subs'], spending_total, 3)
    print_set("\nTen Year Ranking, No SUBs:", rankings['ten_year_ranking_no_subs'], spending_total, 10)
    puts "Took #{Time.now - time} seconds"
  end

  def print_set(title, ranks, spending_total, years)
    puts title
    10.times.each do |idx|
      break if ranks[idx].nil?

      puts "#{ranks[idx].join(' - ')}, Rate: #{(ranks[idx].first / (spending_total * years) * 100).round(2)}%"
    end
  end
end
