module Abilities
  class Logged
    include CanCan::Ability
    include Abilities::Commons

    def initialize(user)
      r_blog_post_is_public = {status: BlogPost::PUBLISHED}

      can :create, Proposal do |proposal|
        proposal.group_proposals.empty?
      end
      can :create, Proposal, group_proposals: {group: can_do_on_group(user, GroupAction::PROPOSAL_INSERT)}

      # can see proposals in groups in which has permission, not belonging to any area
      can :show, Proposal, group_proposals: {group: can_do_on_group(user, GroupAction::PROPOSAL_VIEW)}

      # but can't see proposals in presentation areas. it will be allowed in next condition
      cannot :show, Proposal do |proposal|
        proposal.private && !proposal.visible_outside && proposal.presentation_areas.count > 0
      end

      # can see proposals in group areas in which has permission
      can :show, Proposal, presentation_areas: can_do_on_group_area(user, GroupAction::PROPOSAL_VIEW)

      can [:edit, :update, :geocode, :add_authors, :available_authors_list],
          Proposal, users: {id: user.id}, proposal_state_id: ProposalState::VALUTATION

      can [:rankup, :rankdown], Proposal do |proposal|
        ranking = proposal.rankings.find_by(user_id: user.id)
        if ranking
          ranking.updated_at < proposal.updated_at
        else
          can? :participate, proposal
        end
      end

      can :available_author, Proposal do |proposal|
        (proposal.users.exclude? user) &&
          (can? :participate, proposal)
      end

      # he can participate to public proposals
      can :participate, Proposal, private: false
      # in groups
      can :participate, Proposal, group_proposals: {group: can_do_on_group(user, GroupAction::PROPOSAL_PARTICIPATION)}

      # but can't see proposals in presentation areas. it will be allowed in next condition
      cannot :participate, Proposal do |proposal|
        proposal.presentation_areas.count > 0
      end
      # in areas
      can :participate, Proposal, presentation_areas: can_do_on_group_area(user, GroupAction::PROPOSAL_PARTICIPATION)

      # can never participate if not in valutation or voted
      cannot :participate, Proposal,
             proposal_state_id: [ProposalState::WAIT_DATE, ProposalState::WAIT,
                                 ProposalState::VOTING, ProposalState::REVISION, ProposalState::ABANDONED]

      can :vote, Proposal, private: false, proposal_state_id: ProposalState::VOTING
      can :vote, Proposal,
          proposal_state_id: ProposalState::VOTING,
          group_proposals: {group: can_do_on_group(user, GroupAction::PROPOSAL_VOTE)}
      can :vote, Proposal,
          proposal_state_id: ProposalState::VOTING,
          presentation_areas: can_do_on_group_area(user, GroupAction::PROPOSAL_VOTE)

      # can't vote if has already voted
      cannot :vote, Proposal, user_votes: {user_id: user.id}

      can :set_votation_date, Proposal, proposal_state_id: ProposalState::WAIT_DATE, users: {id: user.id}

      can :set_votation_date, Proposal do |proposal| # return true if the user can put the proposal in votation
        (proposal.updated_at < (Time.now - OTHERS_CHOOSE_VOTE_DATE_DAYS.days)) &&
          proposal.private? &&
          can_do_on_group?(user, proposal.groups.first, GroupAction::PROPOSAL_DATE)
      end

      can :regenerate, Proposal, proposal_state_id: ProposalState::ABANDONED, private: false
      can :regenerate, Proposal,
          proposal_state_id: ProposalState::ABANDONED,
          group_proposals: {group: can_do_on_group(user, GroupAction::PROPOSAL_INSERT)}

      can :destroy, Proposal do |proposal|
        (proposal.users.include? user) &&
          !(((Time.now - proposal.created_at) > 10.minutes) &&
            (proposal.valutations > 0 || proposal.contributes.count > 0)) && proposal.in_valutation?
      end

      can :unintegrate, ProposalComment, user: {id: user.id}, integrated: true

      # TODO: better check for manage_noise and mark noise permissions
      can [:index, :list, :edit_list, :left_list, :show_all_replies, :manage_noise, :mark_noise], ProposalComment
      can [:show, :history, :report], ProposalComment, user_id: user.id
      can [:show, :history, :report], ProposalComment,
          proposal: {groups: can_do_on_group(user, GroupAction::PROPOSAL_VIEW)}
      can :create, ProposalComment, proposal: {private: false}
      can :create, ProposalComment, proposal: {groups: can_do_on_group(user, GroupAction::PROPOSAL_PARTICIPATION)}

      cannot :create, ProposalComment do |_proposal_comment|
        LIMIT_COMMENTS &&
          user.last_proposal_comment &&
          (user.last_proposal_comment.created_at > COMMENTS_TIME_LIMIT.ago)
      end

      can :update, ProposalComment, user: {id: user.id}

      can :destroy, ProposalComment do |proposal_comment|
        (proposal_comment.user_id == user.id) &&
          (proposal_comment.created_at > 5.minutes.ago)
      end

      can [:rankup, :rankdown, :ranknil], ProposalComment do |comment|
        can? :participate, comment.proposal
      end

      can :new, ProposalSupport
      can :create, ProposalSupport do |support|
        user.groups.include? support.group
      end

      can :new, Group
      can :create, Group do |_group|
        !LIMIT_GROUPS || !user.portavoce_groups.maximum(:created_at) ||
          (user.portavoce_groups.maximum(:created_at) < GROUPS_TIME_LIMIT.ago)
      end

      can :read, Group
      can [:update, :enable_areas, :change_advanced_options,
           :change_default_anonima, :change_default_visible_outside,
           :change_default_secret_vote], Group, admin_of_group?(user)
      can :create, SearchParticipant, group: participate_in_group(user)

      can :destroy, Group do |group|
        (group.portavoce.include? user) && (group.participants.count < 2)
      end

      can :remove_post, Group, admin_of_group?(user)

      can [:view_documents, :reload_storage_size], Group, can_do_on_group(user, GroupAction::DOCUMENTS_VIEW)
      can :manage_documents, Group, can_do_on_group(user, GroupAction::DOCUMENTS_MANAGE)

      can :post_to, Group, can_do_on_group(user, GroupAction::STREAM_POST)

      can :create_event, Group, can_do_on_group(user, GroupAction::CREATE_EVENT)

      can :support_proposal, Group, can_do_on_group(user, GroupAction::SUPPORT_PROPOSAL)
      can :accept_requests, Group, can_do_on_group(user, GroupAction::REQUEST_ACCEPT)

      can :view_proposal, Group, admin_of_group?(user)
      can :view_proposal, Group, can_do_on_group(user, GroupAction::PROPOSAL_VIEW)

      can :insert_proposal, Group, can_do_on_group(user, GroupAction::PROPOSAL_INSERT)

      can :create_date, Group, can_do_on_group(user, GroupAction::PROPOSAL_DATE)

      can :create_any_event, Group do |group|
        (can? :create_date, group) && (can? :create_event, group)
      end

      can :view_data, Group, private: false
      can [:view_data, :permissions_list], Group, group_participations: {user_id: user.id}

      can [:read, :create, :update, :change_group_permission], ParticipationRole, group: admin_of_group?(user)
      can :destroy, ParticipationRole do |participation_role|
        participation_role.id != participation_role.group.participation_role_id
      end

      can [:read, :create, :update, :destroy, :change], AreaRole, group_area: {group: admin_of_group?(user)}
      cannot :destroy, AreaRole do |area_role|
        area_role.id == area_role.group_area.area_role_id
      end

      can :view_proposal, GroupArea, group: admin_of_group?(user)
      can :view_proposal, GroupArea, can_do_on_group_area(user, GroupAction::PROPOSAL_VIEW)

      can :insert_proposal, GroupArea, group: admin_of_group?(user)
      can :insert_proposal, GroupArea, can_do_on_group_area(user, GroupAction::PROPOSAL_INSERT)

      can :update, GroupArea do |area|
        area.group.portavoce.include? user
      end
      can :destroy, GroupArea do |area|
        (area.group.portavoce.include? user) && area.proposals.empty?
      end

      # should be you, and proposal must have more users
      can :destroy, ProposalPresentation do |presentation|
        presentation.user == user && presentation.proposal.users.count > 1
      end

      can :show_tooltips, User, show_tooltips: true

      # must have an email
      if user.email
        # can send messages if receiver has enabled it
        can :send_message, User, receive_messages: true
        # can't send messages if receiver has not an email address
        cannot :send_message, User, email: nil
        # cannot send messages to himself
        cannot :send_message, User, id: user.id
      end

      can :index, [GroupParticipation, GroupArea], group: participate_in_group(user)

      can [:read, :dates], [Quorum, BestQuorum, OldQuorum], group: participate_in_group(user)
      can [:read, :dates], [Quorum, BestQuorum, OldQuorum], public: true

      can :manage, [Quorum, BestQuorum, OldQuorum], group_quorum: {group: admin_of_group?(user)}
      can :manage, GroupArea, group: admin_of_group?(user).merge(enable_areas: true)

      can [:create, :destroy], AreaParticipation, group_area: {group: admin_of_group?(user)}

      # e sia l'amministratore o portavoce del gruppo
      # e che il ruolo appartenga al gruppo indicato o sia generico,
      # e l'utente a cui si modifica il ruolo appartenga al gruppo
      # e non si stia cambiando il ruolo dell'unico amministratore
      can :change_user_permission, GroupParticipation do |group_participation|
        puser = group_participation.user
        role = group_participation.participation_role
        group = group_participation.group
        (group.portavoce.include? user) && # check user is administrator
          (!role.group || (role.group == group)) && # check role is a group role
          (!(group.portavoce.include? puser) || (group.portavoce.count > 1)) # check user is not the only administrator
      end

      can :destroy, GroupParticipation do |group_participation|
        ((group_participation.participation_role_id != ParticipationRole.admin.id ||
          group_participation.group.portavoce.count > 1) &&
          user == group_participation.user) ||
          ((group_participation.group.portavoce.include? user) && (group_participation.user != user))
      end

      can [:new, :create], GroupInvitation, group: can_do_on_group(user, GroupAction::REQUEST_ACCEPT)

      # can destroy an identity provider only if the set a valid email address
      can :destroy, Authentication do |authentication|
        user == authentication.user && user.email
      end

      can [:edit, :update, :destroy], Blog, user_id: user.id
      can [:new, :create], Blog unless user.blog

      can :read, BlogPost, status: BlogPost::RESERVED, groups: participate_in_group(user)
      can :read, PostPublishing, blog_post: {status: BlogPost::RESERVED, groups: participate_in_group(user)}

      can :drafts, BlogPost, status: BlogPost::DRAFT, user_id: user.id
      can :read, BlogPost, user_id: user.id
      can :read, PostPublishing, blog_post: {user_id: user.id}

      can [:edit, :update, :destroy], BlogPost, user_id: user.id
      if user.blog
        can :create, BlogPost, blog: {user_id: user.id}
        can :create, BlogPost, publishings: {group: participate_in_group(user)}
      end

      can :create, BlogComment, blog_post: r_blog_post_is_public
      can :create, BlogComment, blog_post: {user_id: user.id}
      can :create, BlogComment, blog_post: {groups: participate_in_group(user)}

      can :destroy, BlogComment, user_id: user.id
      can :destroy, BlogComment, blog_post: {user_id: user.id}

      can :change_rotp_enabled, User if user.email

      # can also view private events of groups in which participates
      can :read, Event, groups: participate_in_group(user)

      can :create, Event

      can [:update, :destroy], Event, user_id: user.id # can update my event
      can [:update, :destroy], Event, groups: admin_of_group?(user)
      cannot [:update, :destroy], Event do |event|
        event.proposals.any? || event.possible_proposals.any?
      end

      can [:read, :check], Alert, user_id: user.id

      can :update, ProposalNickname,
          ["user_id = #{user.id} and created_at > :limit", limit: 10.minutes.ago] do |proposal_nickname|
        proposal_nickname.user_id == user.id && proposal_nickname.created_at > 10.minutes.ago
      end

      can [:create, :like], EventComment, event: {groups: participate_in_group(user)}
      can [:create, :like], EventComment, event: {private: false}

      can :destroy, EventComment, user_id: user.id

      can :create, MeetingParticipation, meeting: {event: {private: false}}
      can :create, MeetingParticipation, meeting: {event: {groups: participate_in_group(user)}}
      cannot :create, MeetingParticipation, meeting: {event: ['endtime < :limit', limit: Time.now]}

      # forum permissions
      can :read, Frm::Category, group: participate_in_group(user)
      can :read, Frm::Forum, group: participate_in_group(user)
      can :read, Frm::Topic, forum: {group: participate_in_group(user)}
      can [:create, :update, :destroy, :toggle_hide, :toggle_lock, :toggle_pin], Frm::Topic do |topic|
        topic.forum.group.portavoce.include? user
      end

      can :manage, Frm::Category, group: admin_of_group?(user)
      can :manage, Frm::Forum, group: admin_of_group?(user)

      can :manage, Frm::Mod, group: admin_of_group?(user)

      can :create_topic, Frm::Forum, group: participate_in_group(user)

      can [:new, :create], Frm::Topic, forum: {group: participate_in_group(user)}
      can [:update, :destroy], Frm::Topic, user_id: user.id

      can [:reply, :subscribe, :unsubscribe], Frm::Topic, forum: {group: participate_in_group(user)}

      can :edit_post, Frm::Forum, group: participate_in_group(user)

      can :moderate, Frm::Forum do |forum|
        user.can_moderate_forem_forum?(forum) || user.forem_admin?(forum.group)
      end

      can :create, Frm::Post, group: participate_in_group(user)
      can :update, Frm::Post, user_id: user.id
      can :update, Frm::Post, group: admin_of_group?(user)
      can :destroy, Frm::Post do |post|
        post.owner_or_moderator? user
      end

      # Always performed
      can :access, :ckeditor # needed to access Ckeditor filebrowser

      # Performed checks for actions:
      # TODO: ckeditor assets are public. make them reserved on a per-user basis
      can [:read, :create, :destroy], Ckeditor::Picture, assetable_id: user.id
      can [:read, :create, :destroy], Ckeditor::AttachmentFile, assetable_id: user.id
    end
  end
end
