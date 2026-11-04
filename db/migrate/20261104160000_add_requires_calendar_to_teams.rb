class AddRequiresCalendarToTeams < ActiveRecord::Migration[7.1]
  def up
    add_column :teams, :requires_calendar, :boolean, default: false, null: false
    # Doctors used to be recognized by a team named Médicos; that team keeps its members' calendars.
    execute "UPDATE teams SET requires_calendar = true WHERE translate(lower(name), 'éÉ', 'ee') IN ('medicos', 'medico')"
  end

  def down
    remove_column :teams, :requires_calendar
  end
end
