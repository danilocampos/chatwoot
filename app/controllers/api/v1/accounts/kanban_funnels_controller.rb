class Api::V1::Accounts::KanbanFunnelsController < Api::V1::Accounts::BaseController
  before_action :authorize_funnel!

  def index
    render json: Current.account.kanban_funnels.order(:id).as_json(only: [:id, :name, :stages])
  end

  def create
    funnel = Current.account.kanban_funnels.create!(funnel_params)
    render json: funnel.as_json(only: [:id, :name, :stages]), status: :created
  end

  def update
    funnel = Current.account.kanban_funnels.find(params[:id])
    funnel.with_lock { funnel.update!(funnel_params) }
    render json: funnel.as_json(only: [:id, :name, :stages])
  end

  private

  def authorize_funnel!
    authorize KanbanFunnel
  end

  def funnel_params
    params.require(:funnel).permit(:name, stages: [:id, :name])
  end
end
