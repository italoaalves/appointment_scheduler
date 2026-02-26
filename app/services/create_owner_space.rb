# frozen_string_literal: true

class CreateOwnerSpace
  def self.call(user)
    new(user).call
  end

  def initialize(user)
    @user = user
  end

  def call
    return unless @user.can?(:own_space) && !SpaceMembership.exists?(user_id: @user.id)

    space = Space.new(name: @user.name.presence || @user.email)
    space.owner_id = @user.id
    space.save!
    SpaceMembership.create!(user_id: @user.id, space_id: space.id)
    space
  end
end
