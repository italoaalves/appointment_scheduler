# frozen_string_literal: true

class CreateOwnerSpace
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return unless @user.can?(:own_space) && @user.space_id.nil?

    space = Space.new(name: @user.name.presence || @user.email)
    space.owner_id = @user.id
    space.save!
    @user.update_column(:space_id, space.id)
    space
  end
end
