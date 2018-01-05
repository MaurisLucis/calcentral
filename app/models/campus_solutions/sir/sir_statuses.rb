module CampusSolutions
  module Sir
    class SirStatuses < UserSpecificModel

      include Cache::CachedFeed
      include Cache::UserCacheExpiry
      include Cache::RelatedCacheKeyTracker
      include LinkFetcher
      include User::Identifiers

      HEADER_DATA = {
        GENERIC: {
          background: 'cc-widget-sir-background-berkeley'
        },
        GRADDIV: {
          name: 'Fiona M. Doyle',
          title: 'Dean of the Graduate Division',
          background: 'cc-widget-sir-background-berkeley',
          picture: 'cc-widget-sir-picture-grad'
        },
        HAASGRAD: {
          name: 'Richard Lyons',
          title: 'Haas School of Business, Dean',
          background: 'cc-widget-sir-background-haasgrad',
          picture: 'cc-widget-sir-picture-haasgrad'
        },
        LAW: {
          background: 'cc-widget-sir-background-lawjd'
        },
        UGRD: {
          name: 'Amy W. Jarich',
          title: 'Assistant Vice Chancellor & Director',
          background: 'cc-widget-sir-background-berkeley',
          picture: 'cc-widget-sir-picture-ugrad'
        }
      }

      LINK_IDS = {
        coaFreshmanLink: 'UC_ADMT_COND_FRESH',
        coaTransferLink: 'UC_ADMT_COND_TRANS',
        firstYearPathwayLink: 'UC_ADMT_FYP_SELECT'
      }

      def get_feed_internal
        sir_checklist_items = get_sir_checklist_items
        {
          sirStatuses: sir_checklist_items
        }
      end

      def get_sir_checklist_items
        checklist_feed = CampusSolutions::MyChecklist.new(@uid).get_feed
        checklist_items = checklist_feed.try(:[], :feed).try(:[], :checkListItems)
        if checklist_items.nil?
          return nil
        else
          extract_sir_checklist_items(checklist_items)
        end
      end

      def extract_sir_checklist_items(checklist_items)
        sir_checklist_items = []
        checklist_items.try(:each) do |checklist_item|
          sir_checklist_items.push(checklist_item) if checklist_item.try(:[], :adminFunc) == 'ADMP'
        end
        map_sir_configs(sir_checklist_items)
      end

      def map_sir_configs(sir_checklist_items)
        sir_config = (CampusSolutions::Sir::SirConfig.new().get).try(:[], :feed).try(:[], :sirConfig)
        sir_checklist_items.try(:delete_if) do |item|
          relevant_sir_config = find_relevant_sir_config_form(item, sir_config.try(:[], :sirForms))
          if not relevant_sir_config.nil?
            item[:config] = relevant_sir_config
            item[:responseReasons] = find_relevant_response_reasons(item, sir_config.try(:[], :responseReasons))
            item[:isUndergraduate] = item.try(:[], :checkListMgmtAdmp).try(:[], :acadCareer) == 'UGRD'
          end
          relevant_sir_config.nil?
        end
        add_undergraduate_new_admit_attributes(sir_checklist_items)
      end

      def add_undergraduate_new_admit_attributes(sir_checklist_items)
        sir_checklist_items.try(:each) do |item|
          if is_complete_undergraduate_item?(item)
            application_nbr = item.try(:[], :checkListMgmtAdmp).try(:[], :admApplNbr).try(:to_s)
            cs_id = lookup_campus_solutions_id
            new_admit_attributes = {
              visible: add_visibility_flag,
              links: get_undergraduate_new_admit_links(cs_id, application_nbr)
            }
            item[:newAdmitAttributes] = new_admit_attributes
          end
        end
        add_header_info(sir_checklist_items)
      end

      def add_visibility_flag
        expiration_date = Settings.new_admit_expiration_date
        current_date = Settings.terms.fake_now || DateTime.now
        current_date <= expiration_date
      end

      def get_undergraduate_new_admit_links(campus_solutions_id, application_nbr)
        new_admit_attributes = EdoOracle::Queries.get_new_admit_status(campus_solutions_id, application_nbr)
        link_configuration = {
          coaFreshmanLink: new_admit_attributes.try(:[], 'admit_type') == 'FYR' && new_admit_attributes.try(:[], 'athlete') == 'N',
          coaTransferLink: new_admit_attributes.try(:[], 'admit_type') == 'TRN' || new_admit_attributes.try(:[], 'athlete') == 'Y',
          firstYearPathwayLink: new_admit_attributes.try(:[], 'admit_type') == 'FYR' && new_admit_attributes.try(:[], 'athlete') == 'N' && ['UCLS', 'UCNR'].include?(new_admit_attributes.try(:[], 'applicant_program'))
        }
        add_undergraduate_new_admit_links link_configuration
      end

      def add_undergraduate_new_admit_links(link_configuration)
        links = {}
        link_configuration.try(:each) do |link_key, link_visible|
          if link_visible
            link = fetch_link(LINK_IDS[link_key])
            links[link_key] = link
          end
        end
        link_configuration.merge!(links)
      end

      def add_header_info(sir_checklist_items)
        sir_checklist_items.try(:each) do |item|
          header_cd = (item.try(:[], :config).try(:[], :ucSirImageCd)).try(:to_sym)
          header_info = header_cd.nil? ? HEADER_DATA.try(:[], :GENERIC) : HEADER_DATA.try(:[], header_cd)
          item[:header] = header_info
        end
        add_deposit_info(sir_checklist_items)
      end

      def add_deposit_info(sir_checklist_items)
        sir_checklist_items.try(:each) do |item|
          deposit = { required: false }
          if is_incomplete? item
            adm_appl_nbr = item.try(:[], :checkListMgmtAdmp).try(:[], :admApplNbr).try(:to_s)
            deposit_info = unpack_deposit_response MyDeposit.new(@uid, adm_appl_nbr: adm_appl_nbr).get_feed
            deposit.merge!(deposit_info)
            deposit[:required] = deposit_due? deposit.try(:[], :dueAmt)
          end
          item[:deposit] = deposit
        end
      end

      def is_incomplete?(checklist_item)
        ['I', 'R'].include?(checklist_item.try(:[], :itemStatusCode))
      end

      def is_complete_undergraduate_item?(checklist_item)
        checklist_item.try(:[], :itemStatusCode) == 'C' && checklist_item.try(:[], :isUndergraduate)
      end

      def unpack_deposit_response(deposit_response)
        deposit_response.try(:[], :feed).try(:[], :depositResponse).try(:[], :deposit)
      end

      def deposit_due?(deposit_amt)
        !deposit_amt.nil? && deposit_amt != 0
      end

      def find_relevant_sir_config_form(checklist_item, sir_config_forms)
        sir_config_forms.try(:find) do |form|
          form.try(:[], :chklstItemCd) == checklist_item.try(:[], :chklstItemCd)
        end
      end

      def find_relevant_response_reasons(checklist_item, sir_config_response_reasons)
        sir_config_response_reasons.try(:select) do |reason|
          reason.try(:[], :acadCareer) == checklist_item.try(:[], :config).try(:[], :acadCareer)
        end
      end

    end
  end
end
