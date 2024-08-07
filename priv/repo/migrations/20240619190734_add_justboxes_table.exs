defmodule Justrunit.Repo.Migrations.AddJustboxesTable do
  use Ecto.Migration

  def change do
    create table(:justboxes) do
      add :name, :string, null: false, unique: true
      add :slug, :string, null: false, unique: true
      add :description, :string, null: false
      timestamps()
    end
  end
end
