#!/usr/bin/env ruby
require "json"
require "fileutils"

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

def build_distractors(correct, paper, topic_distractors)
  candidates = (paper["concepts"] - [correct]) + topic_distractors.fetch(paper["topic"], [])
  candidates.uniq.first(3)
end

templates = [
  lambda do |paper, concept, distractors, index|
    {
      "prompt" => "Which concept is most closely associated with #{paper['author']}'s #{paper['year']} work \"#{paper['title']}\"?",
      "correct" => concept,
      "incorrect" => distractors
    }
  end,
  lambda do |paper, concept, distractors, index|
    {
      "prompt" => "In the context of \"#{paper['title']}\", which idea best matches the paper's core contribution?",
      "correct" => concept,
      "incorrect" => distractors.rotate(index % 3)
    }
  end,
  lambda do |paper, concept, distractors, index|
    {
      "prompt" => "#{paper['title']} is most often taught as a foundation for which of the following ideas?",
      "correct" => concept,
      "incorrect" => distractors.reverse
    }
  end,
  lambda do |paper, concept, distractors, index|
    {
      "prompt" => "A student revising #{paper['topic'].downcase} would link \"#{paper['title']}\" most directly to which term?",
      "correct" => concept,
      "incorrect" => distractors
    }
  end,
  lambda do |paper, concept, distractors, index|
    {
      "prompt" => "Which answer would best identify the central mechanism highlighted in #{paper['author']}'s \"#{paper['title']}\"?",
      "correct" => concept,
      "incorrect" => distractors.rotate((index + 1) % 3)
    }
  end
]

questions = []
counter = 1

until questions.length >= 1000
  papers.each do |paper|
    paper["concepts"].each_with_index do |concept, concept_index|
      distractors = build_distractors(concept, paper, topic_distractors)
      next if distractors.length < 3

      templates.each_with_index do |template, template_index|
        variant = template.call(paper, concept, distractors, concept_index + template_index)
        answer_pool = ([variant["correct"]] + variant["incorrect"]).uniq.first(4)
        next unless answer_pool.length == 4

        correct_text = variant["correct"]
        rotated = answer_pool.rotate((counter + template_index) % 4)
        answers = rotated.map.with_index do |text, answer_index|
          {
            "id" => "q#{counter}-a#{answer_index + 1}",
            "text" => text,
            "correct" => text == correct_text
          }
        end

        questions << {
          "id" => "q#{counter}",
          "paperId" => paper["id"],
          "paperTitle" => paper["title"],
          "topic" => paper["topic"],
          "prompt" => variant["prompt"],
          "explanation" => "#{paper['author']}'s #{paper['year']} work is commonly cited for #{concept}. Review the source paper for the original framing and surrounding argument.",
          "sourceUrl" => paper["sourceUrl"],
          "jstorUrl" => paper["jstorUrl"],
          "answers" => answers
        }
        counter += 1
        break if questions.length >= 1000
      end
      break if questions.length >= 1000
    end
    break if questions.length >= 1000
  end
end

File.write(output_path, JSON.pretty_generate(questions))
puts "Generated #{questions.length} questions into #{output_path}"
