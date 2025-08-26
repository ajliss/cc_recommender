# frozen_string_literal: true

require 'json'

class RewardsCalculatorV4Web
  def initialize(opts)
    @flags = opts.fetch(:flags, {})
    @spending = opts.fetch(:spending, {})
    @reward_programs_points_values = opts.fetch(:reward_programs_points_values, {})
    @excluded_cards = opts.fetch(:excluded_cards, {})
    @ineligible_subs = opts.fetch(:ineligible_subs, {})
    @required_cards = opts.fetch(:required_cards, {})
  end

  def run(combo_size)
    # time = Time.now
    # combinations
    combos = get_cc_combinations(combo_size)
    # calculate
    reward_hashes = calculate_rewards(combos)
    # rank
    rankings = calculate_rankings(reward_hashes)

    spending_total = sum_spending

    final_rankings = finalize_rankings(rankings)
    [final_rankings, spending_total]
  end

  def finalize_rankings(rankings)
    rankings.transform_values do |array|
      array.slice(0...10)
    end
  end

  def get_cc_combinations(size)
    cards = []
    combinations = []
    Dir.each_child('Cards') do |x|
      card = JSON.parse(File.read(File.open(File.join(File.expand_path('./cards'), x))))

      next if @excluded_cards[card['full name']]
      next if !@flags['AF'] && card['Annual Fee'].positive?

      card['rewards'] = { 'total' => [0, 0] }
      if card['Program Type'] == 'Upgradeable' && @flags['cashback only']
        card['Program Type'] == card['Default Program Type']
      end

      cards << card
    end
    cards.combination(size) { |combo| combinations << combo.map { |c| deep_clone(c) } }
    filter_combinations(combinations)
  end

  def deep_clone(obj)
    obj.clone.tap do |new_obj|
      new_obj.each do |key, val|
        new_obj[key] = deep_clone(val) if val.is_a?(Hash)
        new_obj[key] = val.dup if val.is_a?(Array)
      end
    end
  end

  def filter_combinations(combinations)
    combinations.filter do |combo|
      required_card_flag = true

      required_card_flag = required_card?(combo) unless @required_cards.empty?
      next unless required_card_flag

      if @flags['Single Travel card']
        # HACK: reduce combinations of multiple airline/travel cards
        # that overlap too much
        set_reward_programs(combo) unless @flags['Upgradeable points']
        combo.count { |card| card['Travel Card'] } < 2
      else
        false
      end
    end
  end

  def required_card?(combo)
    required_card_names = @required_cards.each_pair.map do |arr|
      arr[0] if arr[1]
    end.compact
    combo_names = combo.map { |c| c['full name'] }
    (required_card_names - combo_names).empty?
  end

  def set_reward_programs(combo)
    return if @flags['Cashback only']

    names = combo.map { |card| card['full name'] }
    combo.each do |card|
      next unless card['Program Type Upgrade']

      card['Program Type Upgrade'].each_pair do |key, val|
        next unless names.include?(key)

        card['Reward Program'] = val[0]
        card['Program Type'] = val[1]
      end
    end
  end

  def calculate_rewards(combos)
    combos.map do |combo|
      # go through spending and assign it to each card by credit, cap and rate
      # and calculate all the rewards from that
      traverse_spending(combo, [], @spending)

      reward_hash = build_rewards_hashes(combo)

      reward_hash
    end
  end

  def traverse_spending(combo, keys, spending_hash)
    spending_hash.each_pair do |key, value|
      keys << key
      if value.instance_of?(::Hash)
        # dig deeper
        traverse_spending(combo, keys, value)
      else
        number = value.to_i
        assign_spending_to_card(combo, keys, number) unless number.zero?
      end
      keys.pop
    end
  end

  def assign_spending_to_card(combo, keys, value)
    # check if monthly credits or caps
    caps_flag, cap_refresh_necessary = any_caps?(combo, keys)
    credits_flag, credit_refresh_necessary = any_credits?(combo, keys)

    if cap_refresh_necessary || credit_refresh_necessary
      # assign spending to card month by month
      (1..12).each do |month|
        refresh_credits_and_caps(combo, keys, month)
        # spend for credits since they have best return rate
        remaining = if credits_flag
                      use_credits(combo, keys, value, caps_flag)
                    else
                      value
                    end

        # spend by best category, taking spending caps into account
        assign_spending_by_category_rate(combo, keys, remaining, caps_flag) if remaining.positive?
        # assign spending by baseline
      end
    elsif credits_flag || caps_flag
      remaining = if credits_flag
                    use_credits(combo, keys, value * 12, caps_flag)
                  else
                    value * 12
                  end
      assign_spending_by_category_rate(combo, keys, remaining, caps_flag) if remaining.positive?
    else
      assign_to_best_category(combo, keys, value * 12)
    end
  end

  def any_caps?(combo, keys)
    cap_flag = false
    combo.each do |card|
      cap = card.dig('Spending Caps', *keys)
      next unless cap

      cap_flag = true
      if cap [1] || cap[3] > 12
        # spending cap that refreshes before a year
        return [cap_flag, true]
      end
    end
    # possible spending cap, but never refreshed if so
    [cap_flag, false]
  end

  def any_credits?(combo, keys)
    credits_flag = false
    combo.each do |card|
      credits = card.dig('Credits', *keys)
      next unless credits

      credits_flag = true
      if credits [1] || credits[3] > 12
        # credits that refresh before a year
        return [credits_flag, true]
      end
    end
    # possible credits, but never refreshed if so
    [credits_flag, false]
  end

  def refresh_credits_and_caps(combo, keys, month)
    combo.each do |card|
      credit_info = card.dig('Credits', *keys)
      cap_info = card.dig('Spending Caps', *keys)
      check_refresh(credit_info, month) if credit_info
      check_refresh(cap_info, month) if cap_info
    end
  end

  def check_refresh(info, month)
    # skip if it does not refresh
    return unless info[1] &&
                  # refresh if it is at or past refresh month
                  (month >= info[2] + info[3] || month == info[3])

    # reset available
    info[0] = info[4]
    # month for next reset, must be later than current month
    info[3] += info[2] while info[3] < month
  end

  def use_credits(combo, keys, spending, caps_flag)
    # sort by size of credit then assign spending to credits
    sort_by_credits(combo, keys).each do |card|
      credit_info = card.dig('Credits', *keys)
      next if credit_info.nil?

      # example: [amount, refresh?, months until refresh, next month refresh, full amount, program info]
      # => [10, true, 1, 1, 10, "Cashback", "Nontransferable"]
      cap_info = card.dig('Spending Caps', *keys) if caps_flag
      next if credit_info[0].zero?

      # TODO: Reduce category cap
      if spending > credit_info.first
        # add rewards to card
        add_credit_rewards(card, credit_info, keys, credit_info[0])
        # record spending against cap if exists
        cap_info[0] = cap_info[0] > credit_info[0] ? cap_info[0] - credit_info[0] : 0 if cap_info
        # reduce spending by credit
        spending -= credit_info.first
        # no more credit left
        credit_info[0] = 0
      else
        add_credit_rewards(card, credit_info, keys, spending)
        # record spending against cap if exists
        cap_info[0] = cap_info[0] > spending ? cap_info[0] - spending : 0 if cap_info
        credit_info[0] -= spending
        # no more spending to assign
        spending = 0
        break
      end
    end
    spending
  end

  def add_credit_rewards(card, info, keys, spent)
    # add rewards info to total and save category rewards
    rewards_rate = info[5] == 'None' ? 0 : rewards_rate(card, keys)
    rewards = rewards_rate * spent
    card['rewards'][keys.join(', ')] ||= [0, 0]
    card['rewards'][keys.join(', ')][0] += spent
    card['rewards'][keys.join(', ')][1] += rewards + spent
    card['rewards']['total'][0] += spent
    card['rewards']['total'][1] += rewards + spent
  end

  def sort_by_credits(combo, keys)
    combo.sort do |a, b|
      b.dig('Credits', *keys)&.first || 0 <=> a.dig('Credits', *keys)&.first || 0
    end
  end

  def assign_in_capped_category(sorted_cards, cap_info, keys, remaining, caps_flag)
    # all capped out
    return 0 if cap_info.first.zero?

    sorted_cards.each do |card|
      if remaining > cap_info.first
        # add rewards to card
        add_category_rewards(card, keys, cap_info[0])
        # reduce remaining by amount spent (up to the cap)
        remaining -= cap_info[0]
        # no more credit left
        cap_info[0] = 0

        # RE-SORT USING CAPPED OUT LOGIC
        remaining = assign_spending_by_category_rate(sorted_cards, keys, remaining, caps_flag)
      else
        add_category_rewards(card, keys, remaining)
        cap_info[0] -= remaining
        remaining = 0
        break
        # no more spending left, so we are done assigning
      end
    end
  end

  def assign_spending_by_category_rate(combo, keys, remaining, caps_flag)
    sorted_cards = sort_by_rate(combo, keys)
    # example: [amount, refresh?, months until refresh, next month refresh, full amount]
    # => [500, true, 1, 1, 500]
    cap_info = sorted_cards.first.dig('Spending Caps', *keys).nil? ? false : sorted_cards.first.dig('Spending Caps', *keys) if caps_flag
    # sometimes the best category has a cap on how much it will give rewards on
    # so we assign what we can to that category, and the rest to the next best, and so on
    if cap_info
      assign_in_capped_category(sorted_cards, cap_info, keys, remaining, caps_flag)
    else
      assign_to_best_category(combo, keys, remaining)
    end
  end

  def assign_to_best_category(combo, keys, remaining)
    add_category_rewards(sort_by_rate(combo, keys).first, keys, remaining)
    0
  end

  def add_category_rewards(card, keys, spent)
    rewards = rewards_rate(card, keys) * spent

    # add to total rewards and save specific category rewards
    card['rewards'][keys.join(', ')] ||= [0, 0]
    card['rewards'][keys.join(', ')][0] += spent
    card['rewards'][keys.join(', ')][1] += rewards
    card['rewards']['total'][0] += spent
    card['rewards']['total'][1] += rewards
  end

  def sort_by_rate(combo, keys)
    combo.sort do |a, b|
      rewards_rate(b, keys) <=> rewards_rate(a, keys)
    end
  end

  def rewards_rate(card, keys)
    cap_info = card.dig('Spending Caps', *keys).nil? ? false : card.dig('Spending Caps', *keys)
    # sometimes the best category has reached it's spending cap, so it doesn't
    # give any more returns
    base_rate = find_rate(card, keys, cap_info)

    # rate depends on cashback only, or value gained from rewards points if applicable
    case card['Program Type']
    when 'Nontransferable'
      base_rate * @reward_programs_points_values['Nontransferable'][card['Reward Program']]
    when 'Transferable'
      if @flags['Cashback only']
        base_rate * @reward_programs_points_values['Transferable'][card['Reward Program']]['Cashback']
      else
        base_rate * @reward_programs_points_values['Transferable'][card['Reward Program']]['Generic Value']
      end
    when 'Airlines'
      if @flags['Cashback only']
        0
      else
        base_rate * @reward_programs_points_values['Airlines'][card['Reward Program']]
      end
    when 'Hotels'
      if @flags['Cashback only']
        0
      else
        base_rate * @reward_programs_points_values['Hotels'][card['Reward Program']]
      end
    end
  end

  def find_rate(card, keys, cap_info)
    if cap_info && cap_info[0].zero?
      card['Baseline']
    else
      card.dig(*keys) || card['Baseline']
    end
  end

  def build_rewards_hashes(combo)
    combo = sort_by_rewards(combo)
    {
      annual_fee: sum_af(combo),
      combo_name: combo.map { |card| card['full name'] }.join(' | '),
      rewards: sum_rewards(combo),
      sub_value: sum_sub_values(combo),
      rewards_by_card: value_by_card(combo)
      # non spending value here?
    }
  end

  def sort_by_rewards(combo)
    combo.sort do |a, b|
      b['rewards']['total'].last <=> a['rewards']['total'].last
    end
  end

  def sum_rewards(combo)
    total_rewards = 0
    combo.each do |card|
      total_rewards += card['rewards']['total'].last
      next unless card.dig('Credits', 'General')

      array = card['Credits']['General']
      total_rewards += determine_value(array.first, array[6], array[5])
    end
    total_rewards
  end

  def sum_af(combo)
    total_af = 0
    combo.sum { |card| total_af += card['Annual Fee'] }
    total_af
  end

  def value_by_card(combo)
    combo.each_with_object({}) do |card, obj|
      obj[card['full name']] = {}
      obj[card['full name']][:rewards] = card['rewards']['total']
      obj[card['full name']][:annual_fee] = card['Annual Fee']
      obj[card['full name']][:sub_value] = sum_sub_values([card])
    end
  end

  def sum_sub_values(combo)
    cash_value = 0
    combo.sum { |card| cash_value += card['Sign up Bonus']['Cash Value'] }
    points_value = sum_sub_points_value(combo)
    combo.sum { |card| points_value += card['Sign up Bonus']['Points Value'] }
    cash_value + points_value
  end

  def sum_sub_points_value(combo)
    points_value = 0
    combo.each do |card|
      next if @ineligible_subs[card['full name']]

      base_value = card['Sign up Bonus']['Points Value']
      points_value += determine_value(base_value, card['Program Type'], card['Reward Program'])
    end
    points_value
  end

  def determine_value(base_value, program_type, reward_program)
    case program_type
    when 'Nontransferable'
      base_value * @reward_programs_points_values['Nontransferable'][reward_program]
    when 'Transferable'
      if @flags['Cashback only']
        base_value * @reward_programs_points_values['Transferable'][reward_program]['Cashback']
      else
        base_value * @reward_programs_points_values['Transferable'][reward_program]['Generic Value']
      end
    when 'Airlines'
      if @flags['Cashback only']
        0
      else
        base_value * @reward_programs_points_values['Airlines'][reward_program]
      end
    when 'Hotels'
      if @flags['Cashback only']
        0
      else
        base_value * @reward_programs_points_values['Hotels'][reward_program]
      end
    end
  end

  def calculate_rankings(reward_hashes)
    rankings = {
      'one_year_ranking' => [],
      'three_year_ranking' => [],
      'five_year_ranking' => [],
      'ten_year_ranking' => [],
      'one_year_ranking_no_subs' => [],
      'three_year_ranking_no_subs' => [],
      'ten_year_ranking_no_subs' => []
    }

    reward_hashes.each do |rewards_obj|
      rankings['one_year_ranking'] << build_rewards_report_line(1, true, rewards_obj)
      rankings['three_year_ranking'] << build_rewards_report_line(3, true, rewards_obj)
      rankings['five_year_ranking'] << build_rewards_report_line(5, true, rewards_obj)
      rankings['ten_year_ranking'] << build_rewards_report_line(10, true, rewards_obj)
      rankings['one_year_ranking_no_subs'] << build_rewards_report_line(1, false, rewards_obj)
      rankings['three_year_ranking_no_subs'] << build_rewards_report_line(3, false, rewards_obj)
      rankings['ten_year_ranking_no_subs'] << build_rewards_report_line(10, false, rewards_obj)
    end

    rankings.each_value do |val|
      val.sort! { |a, b| b.first <=> a.first }
    end
    rankings
  end

  def build_rewards_report_line(years, sub_flag, rewards_obj)
    name = rewards_obj[:combo_name]
    total_rewards = rewards_obj[:rewards] * years
    total_rewards -= rewards_obj[:annual_fee] * years
    total_rewards += rewards_obj[:sub_value] if sub_flag
    line = [total_rewards.round(2), name]

    contributions = []
    rewards_obj[:rewards_by_card].each_pair do |key, obj|
      total_rewards = obj[:rewards].last * years
      total_rewards -= obj[:annual_fee] * years
      total_rewards += obj[:sub_value] if sub_flag
      contributions << [key, total_rewards.round(2)]
    end
    contributions.sort! { |a, b| b.last <=> a.last }
    line + contributions << years
  end

  def sum_spending
    arr = []
    @spending.each_value do |val|
      if val.instance_of?(::Hash)
        find_ints(val, arr)
      else
        arr << val.to_i
      end
    end
    arr.sum * 12
  end

  def find_ints(obj, arr)
    obj.each_value do |val|
      if val.instance_of?(::Hash)
        find_ints(val, arr)
      else
        arr << val.to_i
      end
    end
  end
end
