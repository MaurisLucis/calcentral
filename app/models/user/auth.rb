module User
  class Auth < ApplicationRecord
    include ActiveRecordHelper

    self.table_name = 'user_auths'

    after_initialize :log_access

    def self.get(uid)
      user_auth = uid.nil? ? nil : User::Auth.where(:uid => uid.to_s).first
      if user_auth.blank?
        # user's anonymous, or is not in the user_auth table, so give them an active status with zero permissions.
        user_auth = User::Auth.new(uid: uid, is_superuser: false, is_viewer: false, is_canvas_whitelisted: false, active: true)
      end
      user_auth
    end

    def self.new_or_update_superuser!(uid)
      use_pooled_connection {
        Retriable.retriable(:on => ActiveRecord::RecordNotUnique, :tries => 5) do
          user = self.where(uid: uid).first_or_initialize
          user.is_superuser = true
          user.active = true
          user.save
        end
      }
    end

    def self.canvas_whitelist
      use_pooled_connection do
        self.where(is_canvas_whitelisted: true, active: true).select(:uid).collect {|r| r[:uid]}
      end
    end

  end
end
