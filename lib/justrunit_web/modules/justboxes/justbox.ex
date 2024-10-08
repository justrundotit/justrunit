defmodule JustrunitWeb.Modules.Justboxes.Justbox do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}

  @derive {
    Flop.Schema,
    sortable: [:updated_at], filterable: []
  }

  schema "justboxes" do
    field :name, :string
    field :slug, :string
    field :description, :string
    field :s3_key, :string
    belongs_to :user, JustrunitWeb.Modules.Accounts.User, type: :binary_id

    timestamps()
  end

  def changeset(struct \\ %__MODULE__{}, params) do
    struct
    |> cast(params, [:name, :slug, :description, :user_id, :s3_key])
    |> validate_required([:name, :slug, :description, :user_id, :s3_key])
  end
end
