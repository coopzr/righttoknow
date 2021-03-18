# To run this test go to the root of the alaveteli directory and run:
#
# $ bundle exec rspec lib/themes/righttoknow/spec/features/screenshots_feature.rb
#
# This also requires a couple of changes to be made first to alaveteli (until some changes
# are potentially merged)
# * the changes in PR https://github.com/mysociety/alaveteli/pull/6165
# * Add the following (under development) to the Alaveteli Gemfile:
#     gem 'selenium-webdriver'
#     gem "timecop"
#     gem "rmagick"

# This tells config/initializers/theme_loader.rb to load the theme
ALAVETELI_TEST_THEME = 'righttoknow'

require File.expand_path('spec/spec_helper')
require File.expand_path('spec/integration/alaveteli_dsl')

describe 'Take Pro marketing screenshots', js: true do
  # Allow connections to selenium
  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    Capybara.server = :webrick
  end

  def screenshot(name)
    path = page.save_screenshot("screenshot.png")
    i = Magick::ImageList.new(path)
    i.write(File.join(Rails.root, "lib", "themes", ALAVETELI_TEST_THEME, "app", "assets", "images", "alaveteli-pro", "#{name}.jpg"))
  end

  let(:pro_user) { FactoryBot.create(:pro_user, name: "Katherine") }
  let!(:pro_user_session) { login(pro_user) }
  let!(:public_body) { FactoryBot.create(:public_body, :name => 'example') }
  let(:kingston) { FactoryBot.create(:public_body, name: "Kingston Hospital NHS Trust") }
  let(:kent) { FactoryBot.create(:public_body, name: "Kent Police") }
  let(:defence) { FactoryBot.create(:public_body, name: "Ministry of Defence") }
  let(:stirling) { FactoryBot.create(:public_body, name: "Stirling Council") }
  let(:southwark) { FactoryBot.create(:public_body, name: "Southwark Borough Council") }

  it "Pro screenshots" do
    using_pro_session(pro_user_session) do
      now = Time.new(2017, 5, 16, 15, 0, 0)

      Timecop.freeze(now - 5.days) do
        1.times do
          FactoryBot.create(:info_request, :embargoed, :overdue, user: pro_user)
        end
        45.times do
          FactoryBot.create(:info_request, :embargoed, :very_overdue, user: pro_user)
        end
        6.times do
          FactoryBot.create(:info_request, :embargoed, :with_incoming, :awaiting_description, user: pro_user)
        end
        4.times do
          FactoryBot.create(:info_request, :embargoed, :with_incoming, :waiting_clarification, user: pro_user)
        end
        5.times do
          FactoryBot.create(:info_request, :embargoed, :with_incoming, :successful, user: pro_user)
        end
        6.times do
          FactoryBot.create(:info_request, :embargo_expiring, :with_incoming, :successful, user: pro_user)
        end
        5.times do
          FactoryBot.create(:info_request, :embargoed, :with_incoming, :attention_requested, user: pro_user)
        end
        15.times do
          FactoryBot.create(:draft_info_request, user: pro_user)
        end
        5.times do
          r = FactoryBot.create(:info_request, :embargoed, user: pro_user)
          r.info_request_events.first.update(created_at: 2.days.ago)
        end
      end

      Timecop.freeze(now - 190.minutes) do
        FactoryBot.create(:info_request, :embargoed, user: pro_user, title: "Refugee housing provision 2016", public_body: stirling)
      end
      Timecop.freeze(now - 130.minutes) do
        FactoryBot.create(:info_request, :embargoed, user: pro_user, title: "Meeting details", public_body: defence)
      end
      Timecop.freeze(now - 70.minutes) do
        FactoryBot.create(:info_request, :embargoed, user: pro_user, title: "Arrest and cautions 2016", public_body: kent)
      end
      Timecop.freeze(now - 69.minutes) do
        FactoryBot.create(:info_request, :embargoed, user: pro_user, title: "Bed provision", public_body: kingston)
      end

      Timecop.freeze(now) do
        visit "/"
      end

      screenshot("screenshot-dashboard")

      # The user puts in another draft and another request
      Timecop.freeze(now - 68.minutes) do
        FactoryBot.create(:info_request, :embargoed, user: pro_user, title: "Section 106 housing provision", public_body: southwark)
      end
      FactoryBot.create(:draft_info_request, user: pro_user)

      Timecop.freeze(now) do
        visit alaveteli_pro_info_requests_path
      end

      screenshot("screenshot-requests")
    end
  end

  it "Pro Batch screenshot" do
    FactoryBot.create(:public_body, name: "Ministry of Defence")
    FactoryBot.create(:public_body, name: "Ministry of Housing")
    culture = FactoryBot.create(:public_body, name: "Ministry of Culture")
    FactoryBot.create(:public_body, name: "Ministry of Transport")
    FactoryBot.create(:public_body, name: "Ministry of Finance")
    education = FactoryBot.create(:public_body, name: "Ministry of Education")
    business = FactoryBot.create(:public_body, name: "Ministry of Business")
    FactoryBot.create(:public_body, name: "Ministry of Health")

    # Start a draft request
    draft = FactoryBot.create(:draft_info_request_batch, user: pro_user,
                              public_bodies: [business, culture, education])

    update_xapian_index

    using_pro_session(pro_user_session) do
      visit alaveteli_pro_batch_request_authority_searches_path(draft_id: draft)

      fill_in "Search for an authority by name", with: "ministry"
      expect(page).to have_content("Ministry of Defence")

      screenshot("screenshot-batch-selection")
    end
  end

  it "Pro All requests screenshot" do
    using_pro_session(pro_user_session) do
      batch = FactoryBot.build(:info_request_batch, :embargoed, user: pro_user, title: "Organisation charts")

      batch.info_requests = [
        FactoryBot.create(:info_request, :embargoed, :with_incoming, :refused, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Education")),
        FactoryBot.create(:info_request, :embargoed, :with_incoming, :with_incoming, :awaiting_description, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Finance")),
        FactoryBot.create(:info_request, :embargoed, :with_incoming, :partially_successful, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Culture")),
        FactoryBot.create(:info_request, :embargoed, :with_incoming, :successful, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Transport")),
        FactoryBot.create(:info_request, :embargoed, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Justice")),
        FactoryBot.create(:info_request, :embargoed, :with_incoming, :with_incoming, :awaiting_description, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Housing")),
        FactoryBot.create(:info_request, :embargoed, :with_internal_review_request, user: pro_user, public_body: FactoryBot.create(:public_body, name: "Ministry of Business"))
      ]
      batch.info_requests.each do |request|
        request.info_request_events = [ FactoryBot.build(:sent_event, info_request: request) ]
      end
      batch.public_bodies = batch.info_requests.map(&:public_body)
      batch.sent_at = Time.zone.now
      batch.save!

      visit alaveteli_pro_info_requests_path
      find(".batch-request label").click

      screenshot("screenshot-batch-list")
    end
  end
end
