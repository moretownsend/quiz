#!/usr/bin/env ruby
require "json"

ROOT = File.expand_path("..", __dir__)
papers_path = File.join(ROOT, "data", "papers.json")
output_path = File.join(ROOT, "data", "questions.json")
papers_js_path = File.join(ROOT, "data", "papers.js")
questions_js_path = File.join(ROOT, "data", "questions.js")

papers = JSON.parse(File.read(papers_path))

TOPIC_DISTRACTORS = {
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
  "Financial economics" => ["local public goods", "resource scarcity", "comparative advantage", "tatonnement"],
  "Monetary economics" => ["urban land use", "common pool resources", "consumer surplus", "rent theory"],
  "Household economics" => ["speculative attacks", "screening", "bank runs", "common knowledge"],
  "Economics of crime" => ["bid-rent", "trade gains", "adverse selection", "deposit insurance"],
  "Finance" => ["commons governance", "minimum wage", "consumer surplus", "public goods"],
  "Behavioral economics" => ["revealed preference", "marginal productivity", "comparative advantage", "liquidity preference"],
  "Banking" => ["division of labor", "life-cycle saving", "tatonnement", "common-pool resources"],
  "International macroeconomics" => ["consumer surplus", "screening", "deposit insurance", "market signaling"],
  "Endogenous growth" => ["involuntary unemployment", "trade gains", "local public goods", "screening"],
  "Institutional economics" => ["liquidity traps", "random walk", "deposit insurance", "menu costs"],
  "Political economy" => ["credit rationing", "urban unemployment", "rational expectations", "consumer surplus"],
  "Development economics" => ["comparative advantage", "deposit insurance", "tatonnement", "permanent income"],
  "Expectations" => ["commons governance", "bid-rent", "credit rationing", "consumer surplus"],
  "Consumption" => ["fixed exchange rate", "voting with feet", "bank runs", "search frictions"],
  "Resource economics" => ["adverse selection", "specialization", "fiscal competition", "loss aversion"],
  "Public economics" => ["capital deepening", "price signaling", "moral hazard", "search equilibrium"],
  "Public finance" => ["random walk", "banking panics", "urban commuting", "comparative advantage"],
  "Mechanism design" => ["consumption smoothing", "resource exhaustion", "natural experiments", "wage rigidity"],
  "Insurance economics" => ["division of labor", "Phillips curve", "price floor", "fiscal federalism"],
  "Contract theory" => ["natural monopoly", "life-cycle consumption", "local public goods", "comparative advantage"],
  "Urban economics" => ["deposit insurance", "common-pool resources", "aggregate demand", "screening"]
}.freeze

STEMS = [
  lambda do |paper, _concept|
    "Which concept should be identified as the principal analytical contribution of #{paper['author']}'s #{paper['year']} work, \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "In an upper-level economics examination, \"#{paper['title']}\" would most appropriately be associated with which concept?"
  end,
  lambda do |paper, _concept|
    "Which idea is the most academically defensible label for the core contribution of \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "A strong answer script discussing \"#{paper['title']}\" would most likely centre on which concept?"
  end,
  lambda do |paper, _concept|
    "Which concept best captures the enduring significance of \"#{paper['title']}\" within #{paper['topic'].downcase}?"
  end,
  lambda do |paper, _concept|
    "Which term would an examiner most reasonably expect students to connect to \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Which of the following provides the clearest statement of the idea for which \"#{paper['title']}\" is remembered?"
  end,
  lambda do |paper, _concept|
    "When economists reference \"#{paper['title']}\", which concept are they most commonly invoking?"
  end,
  lambda do |paper, _concept|
    "Which concept most directly summarises the main theoretical insight of \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "A marker awarding full credit for knowledge of \"#{paper['title']}\" would expect recognition of which concept?"
  end,
  lambda do |paper, _concept|
    "Which label best fits the key mechanism or proposition identified with \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Within the standard economics curriculum, which concept is most closely linked to \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Which answer most accurately identifies the idea to which \"#{paper['title']}\" made a classic contribution?"
  end,
  lambda do |paper, _concept|
    "Which concept belongs in the first line of a concise professional summary of \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "If students were asked to classify the intellectual contribution of \"#{paper['title']}\", which concept should they select?"
  end,
  lambda do |paper, _concept|
    "Which concept is most appropriately treated as the headline association for \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Which of the following best represents the canonical concept tied to \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Which concept would most likely appear in a high-quality revision note on \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "In professional teaching practice, \"#{paper['title']}\" is most likely to be introduced through which concept?"
  end,
  lambda do |paper, _concept|
    "Which answer is the strongest academic association for #{paper['author']}'s \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "Which idea would best complete the statement: \"#{paper['title']}\" is a landmark reference for ____?"
  end,
  lambda do |paper, _concept|
    "Which concept most accurately identifies the recognised contribution of \"#{paper['title']}\" to economics?"
  end,
  lambda do |paper, _concept|
    "Which option offers the most precise exam-style classification of \"#{paper['title']}\"?"
  end,
  lambda do |paper, _concept|
    "A lecturer setting a closed-book examination on #{paper['topic'].downcase} would most likely use \"#{paper['title']}\" to test knowledge of which concept?"
  end
].freeze

def build_distractors(correct, paper)
  candidates = (paper["concepts"] - [correct]) + TOPIC_DISTRACTORS.fetch(paper["topic"], [])
  candidates.uniq.first(3)
end

def order_distractors(distractors, seed)
  case seed % 4
  when 0 then distractors
  when 1 then distractors.rotate(seed % distractors.length)
  when 2 then distractors.reverse
  else distractors.reverse.rotate(seed % distractors.length)
  end
end

def explanation_for(paper, concept)
  "#{paper['author']}'s #{paper['year']} work is conventionally taught in relation to #{concept}. The linked source provides the paper itself or an authoritative record suitable for verification."
end

questions = []
counter = 1

papers.each do |paper|
  paper["concepts"].each_with_index do |concept, concept_index|
    distractors = build_distractors(concept, paper)
    next if distractors.length < 3

    STEMS.each_with_index do |stem, template_index|
      ordered_distractors = order_distractors(distractors, concept_index + template_index)
      answer_pool = ([concept] + ordered_distractors).uniq.first(4)
      next unless answer_pool.length == 4

      answers = answer_pool.rotate((counter + template_index) % 4).map.with_index do |text, answer_index|
        {
          "id" => "qb2-#{counter}-a#{answer_index + 1}",
          "text" => text,
          "correct" => text == concept
        }
      end

      questions << {
        "id" => "qb2-#{counter}",
        "paperId" => paper["id"],
        "paperTitle" => paper["title"],
        "topic" => paper["topic"],
        "prompt" => stem.call(paper, concept),
        "explanation" => explanation_for(paper, concept),
        "sourceUrl" => paper["sourceUrl"],
        "jstorUrl" => paper["jstorUrl"],
        "answers" => answers
      }
      counter += 1
    end
  end
end

File.write(output_path, JSON.pretty_generate(questions))
File.write(papers_js_path, "window.ECON_MILLIONAIRE_PAPERS = #{JSON.generate(papers)};\n")
File.write(questions_js_path, "window.ECON_MILLIONAIRE_QUESTIONS = #{JSON.generate(questions)};\n")
puts "Generated #{questions.length} replacement questions into #{output_path}"
