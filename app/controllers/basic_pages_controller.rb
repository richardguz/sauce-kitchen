class BasicPagesController < ApplicationController
  layout false, only: :show

  def home
  end

  def show
    render :channel
  end
end
