#!/usr/bin/env ruby
require "json"

ROOT = File.expand_path("..", __dir__)
papers_path = File.join(ROOT, "data", "papers.json")
output_path = File.join(ROOT, "data", "questions.json")

papers = JSON.parse(File.read(papers_path))

topic_distractors = {
  "Classical economics" => ["sticky prices", "rational bubbles", "search frictions", "deposit insurance"],
  "Trade and distribution" => ["adverse selection", "menu costs", "time inconsistency", "deposit insurance"],
  "Price theory" => ["moral hazard", "liquidity traps", "rational expectations", "screening"],
  "General equilibrium" => ["price stickiness", "principal-agent problems", "liquidity preference", "bank runs"],
  "Macroeconomics" => ["bid-rent", "screening", "common pool resources", "comparative advantage"],
  "Information economics" => ["tariff revenue", "Phillips curve", "permanent income", "voting with feet"],
  "Mathematical economics" => ["deposit insurance", "path dependence", "currency attacks", "entitlements"],
  "Game theory" => ["consumer surplus", "comparative advantage", "adverse selection", "steady state"],
  "Growth theory" => ["deposit insurance", "separating equilibrium", "sorting", "fixed exchange rate"],
  "Law and economics" => ["menu costs", "rational bubbles", "life-cycle saving", "voting paradox"],
  "Labor economics" => ["common-pool resources", "Hotelling rule", "liquidity preference", "deposit insurance"],
  "Financial economics" => ["local public goods", "resource scarcity", "comparative advantage", "tâtonnement"],
  "Monetary economics" => ["urban land use", "common pool resources", "consumer surplus", "rent theory"],
  "Household economics" => ["speculative attacks", "screening", "bank runs", "common knowledge"],
  "Economics of crime" => ["bid-rent", "trade gains", "adverse selection", "deposit insurance"],
  "Finance" => ["commons governance", "minimum wage", "consumer surplus", "public goods"],
  "Behavioral economics" => ["revealed preference", "marginal productivity", "comparative advantage", "liquidity preference"],
  "Banking" => ["division of labor", "life-cycle saving", "tâtonnement", "common-pool resources"],
  "International macroeconomics" => ["consumer surplus", "screening", "deposit insurance", "market signaling"],
  "Endogenous growth" => ["involuntary unemployment", "trade gains", "local public goods", "screening"],
  "Institutional economics" => ["liquidity traps", "random walk", "deposit insurance", "menu costs"],
  "Political economy" => ["credit rationing", "urban unemployment", "rational expectations", "consumer surplus"],
  "Development economics" => ["comparative advantage", "deposit insurance", "tâtonnement", "permanent income"],
  "Expectations" => ["commons governance", "bid-rent", "credit rationing", "consumer surplus"],
  "Consumption" => ["fixed exchange rate", "voting with feet", "bank runs", "search frictions"],
  "Resource economics" => ["adverse selection", "specialization", "fiscal competition", "loss aversion"],
  "Public economics" => ["capital deepening", "price signaling", "moral hazard", "search equilibrium"],
  "Public finance" => ["random walk", "banking panics", "urban commuting", "comparative advantage"],
  "Mechanism design" => ["consumption smoothing", "resource exhaustion", "natural experiments", "wage rigidity"],
  "Insurance economics" => ["division of labor", "Phillips curve", "price floor", "fiscal federalism"],
  "Contract theory" => ["natural monopoly", "life-cycle consumption", "local public goods", "comparative advantage"],
  "Urban economics" => ["deposit insurance", "common-pool resources", "aggregate demand", "screening"]
}

PROMPT_TEMPLATES = [
  lambda do |paper, _concept, _distractors|
    "Which concept is most closely associated with #{paper['author']}'s #{paper['year']} work \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept, _distractors|
    "In the context of \"#{paper['title']}\", which idea best matches the paper's core contribution?"
  end,
  lambda do |paper, _concept, _distractors|
    "#{paper['title']} is most often taught as a foundation for which of the following ideas?"
  end,
  lambda do |paper, _concept, _distractors|
    "A student revising #{paper['topic'].downcase} would link \"#{paper['title']}\" most directly to which term?"
  end,
  lambda do |paper, _concept, _distractors|
    "Which answer would best identify the central mechanism highlighted in #{paper['author']}'s \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept, _distractors|
    "If you saw \"#{paper['title']}\" on a reading list, which concept should you expect to revise?"
  end,
  lambda do |paper, _concept, _distractors|
    "Which term best completes this sentence: #{paper['author']}'s \"#{paper['title']}\" is a classic reference for ____?"
  end,
  lambda do |paper, _concept, _distractors|
    "A lecturer cites \"#{paper['title']}\" while explaining #{paper['topic'].downcase}. Which concept is most likely being emphasized?"
  end,
  lambda do |paper, _concept, _distractors|
    "Which of these is the best thematic match for #{paper['author']}'s \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept, _distractors|
    "When students summarize the contribution of \"#{paper['title']}\", which concept usually appears first?"
  end,
  lambda do |paper, _concept, _distractors|
    "Which concept is the strongest anchor point for remembering \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept, _distractors|
    "\"#{paper['title']}\" belongs in a quiz bank primarily because it helped define which idea?"
  end
].freeze

def build_distractors(correct, paper, topic_distractors)
  candidates = (paper["concepts"] - [correct]) + topic_distractors.fetch(paper["topic"], [])
  candidates.uniq.first(3)
end

def rotate_distractors(distractors, seed)
  distractors.rotate(seed % distractors.length)
end

questions = []
counter = 1

papers.each do |paper|
  paper["concepts"].each_with_index do |concept, concept_index|
    distractors = build_distractors(concept, paper, topic_distractors)
    next if distractors.length < 3

    PROMPT_TEMPLATES.each_with_index do |template, template_index|
      prompt = template.call(paper, concept, distractors)
      ordered_distractors =
        case template_index % 4
        when 0 then distractors
        when 1 then rotate_distractors(distractors, concept_index + template_index)
        when 2 then distractors.reverse
        else rotate_distractors(distractors.reverse, concept_index + template_index)
        end

      answer_pool = ([concept] + ordered_distractors).uniq.first(4)
      next unless answer_pool.length == 4

      rotated_answers = answer_pool.rotate((counter + template_index) % 4)
      answers = rotated_answers.map.with_index do |text, answer_index|
        {
          "id" => "q#{counter}-a#{answer_index + 1}",
          "text" => text,
          "correct" => text == concept
        }
      end

      questions << {
        "id" => "q#{counter}",
        "paperId" => paper["id"],
        "paperTitle" => paper["title"],
        "topic" => paper["topic"],
        "prompt" => prompt,
        "explanation" => "#{paper['author']}'s #{paper['year']} work is commonly cited for #{concept}. Review the source paper for the original framing and surrounding argument.",
        "sourceUrl" => paper["sourceUrl"],
        "jstorUrl" => paper["jstorUrl"],
        "answers" => answers
      }
      counter += 1
    end
  end
end

File.write(output_path, JSON.pretty_generate(questions))
puts "Generated #{questions.length} unique questions into #{output_path}"
