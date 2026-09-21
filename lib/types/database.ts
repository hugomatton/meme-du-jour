/**
 * Database types for the `public` schema.
 *
 * Regenerate after every migration instead of editing by hand:
 *   npm run db:types      (supabase gen types typescript --local)
 *
 * This file mirrors the migrations in supabase/migrations.
 */

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type Database = {
  public: {
    Tables: {
      admin_alerts: {
        Row: {
          id: number;
          kind: string;
          payload: Json;
          created_at: string;
        };
        Insert: {
          id?: never;
          kind: string;
          payload: Json;
          created_at?: string;
        };
        Update: {
          id?: never;
          kind?: string;
          payload?: Json;
          created_at?: string;
        };
        Relationships: [];
      };
      blocks: {
        Row: {
          blocker_id: string;
          blocked_id: string;
          created_at: string;
        };
        Insert: {
          blocker_id: string;
          blocked_id: string;
          created_at?: string;
        };
        Update: {
          blocker_id?: string;
          blocked_id?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'blocks_blocker_id_fkey';
            columns: ['blocker_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'blocks_blocked_id_fkey';
            columns: ['blocked_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      comments: {
        Row: {
          id: string;
          meme_id: string;
          user_id: string;
          content: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          meme_id: string;
          user_id: string;
          content: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          meme_id?: string;
          user_id?: string;
          content?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'comments_meme_id_fkey';
            columns: ['meme_id'];
            isOneToOne: false;
            referencedRelation: 'memes';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'comments_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      group_challenges: {
        Row: {
          id: string;
          group_id: string;
          template_id: string;
          date: string;
          published_at: string;
        };
        Insert: {
          id?: string;
          group_id: string;
          template_id: string;
          date: string;
          published_at?: string;
        };
        Update: {
          id?: string;
          group_id?: string;
          template_id?: string;
          date?: string;
          published_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'group_challenges_group_id_fkey';
            columns: ['group_id'];
            isOneToOne: false;
            referencedRelation: 'groups';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'group_challenges_template_id_fkey';
            columns: ['template_id'];
            isOneToOne: false;
            referencedRelation: 'templates';
            referencedColumns: ['id'];
          },
        ];
      };
      group_members: {
        Row: {
          group_id: string;
          user_id: string;
          role: string;
          notif_mode: string;
          joined_at: string;
        };
        Insert: {
          group_id: string;
          user_id: string;
          role?: string;
          notif_mode?: string;
          joined_at?: string;
        };
        Update: {
          group_id?: string;
          user_id?: string;
          role?: string;
          notif_mode?: string;
          joined_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'group_members_group_id_fkey';
            columns: ['group_id'];
            isOneToOne: false;
            referencedRelation: 'groups';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'group_members_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      groups: {
        Row: {
          id: string;
          name: string;
          invite_code: string;
          created_by: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          invite_code?: string;
          created_by: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          invite_code?: string;
          created_by?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'groups_created_by_fkey';
            columns: ['created_by'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      likes: {
        Row: {
          meme_id: string;
          user_id: string;
          created_at: string;
        };
        Insert: {
          meme_id: string;
          user_id: string;
          created_at?: string;
        };
        Update: {
          meme_id?: string;
          user_id?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'likes_meme_id_fkey';
            columns: ['meme_id'];
            isOneToOne: false;
            referencedRelation: 'memes';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'likes_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      memes: {
        Row: {
          id: string;
          group_challenge_id: string;
          user_id: string;
          texts: Json;
          created_at: string;
        };
        Insert: {
          id?: string;
          group_challenge_id: string;
          user_id: string;
          texts: Json;
          created_at?: string;
        };
        Update: {
          id?: string;
          group_challenge_id?: string;
          user_id?: string;
          texts?: Json;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'memes_group_challenge_id_fkey';
            columns: ['group_challenge_id'];
            isOneToOne: false;
            referencedRelation: 'group_challenges';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'memes_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      notification_queue: {
        Row: {
          id: number;
          user_id: string;
          group_id: string;
          meme_id: string;
          created_at: string;
          sent_at: string | null;
        };
        Insert: {
          id?: never;
          user_id: string;
          group_id: string;
          meme_id: string;
          created_at?: string;
          sent_at?: string | null;
        };
        Update: {
          id?: never;
          user_id?: string;
          group_id?: string;
          meme_id?: string;
          created_at?: string;
          sent_at?: string | null;
        };
        Relationships: [
          {
            foreignKeyName: 'notification_queue_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'notification_queue_group_id_fkey';
            columns: ['group_id'];
            isOneToOne: false;
            referencedRelation: 'groups';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'notification_queue_meme_id_fkey';
            columns: ['meme_id'];
            isOneToOne: false;
            referencedRelation: 'memes';
            referencedColumns: ['id'];
          },
        ];
      };
      profiles: {
        Row: {
          id: string;
          pseudo: string;
          avatar_url: string | null;
          accepted_terms_at: string;
          created_at: string;
        };
        Insert: {
          id: string;
          pseudo: string;
          avatar_url?: string | null;
          accepted_terms_at: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          pseudo?: string;
          avatar_url?: string | null;
          accepted_terms_at?: string;
          created_at?: string;
        };
        Relationships: [];
      };
      push_tokens: {
        Row: {
          user_id: string;
          token: string;
          platform: string;
          updated_at: string;
        };
        Insert: {
          user_id: string;
          token: string;
          platform: string;
          updated_at?: string;
        };
        Update: {
          user_id?: string;
          token?: string;
          platform?: string;
          updated_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'push_tokens_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      reports: {
        Row: {
          id: string;
          reporter_id: string;
          target_type: string;
          target_id: string;
          reason: string;
          status: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          reporter_id: string;
          target_type: string;
          target_id: string;
          reason: string;
          status?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          reporter_id?: string;
          target_type?: string;
          target_id?: string;
          reason?: string;
          status?: string;
          created_at?: string;
        };
        Relationships: [
          {
            foreignKeyName: 'reports_reporter_id_fkey';
            columns: ['reporter_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
      templates: {
        Row: {
          id: string;
          image_path: string;
          width: number;
          height: number;
          text_zones: Json;
          source: string;
          license: string;
          active: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          image_path: string;
          width: number;
          height: number;
          text_zones: Json;
          source: string;
          license: string;
          active?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          image_path?: string;
          width?: number;
          height?: number;
          text_zones?: Json;
          source?: string;
          license?: string;
          active?: boolean;
          created_at?: string;
        };
        Relationships: [];
      };
    };
    Views: {
      groups_template_stock: {
        Row: {
          group_id: string | null;
          name: string | null;
          remaining: number | null;
        };
        Relationships: [];
      };
      memes_with_stats: {
        Row: {
          id: string | null;
          group_challenge_id: string | null;
          user_id: string | null;
          texts: Json | null;
          created_at: string | null;
          like_count: number | null;
          comment_count: number | null;
          liked_by_me: boolean | null;
        };
        Relationships: [
          {
            foreignKeyName: 'memes_group_challenge_id_fkey';
            columns: ['group_challenge_id'];
            isOneToOne: false;
            referencedRelation: 'group_challenges';
            referencedColumns: ['id'];
          },
          {
            foreignKeyName: 'memes_user_id_fkey';
            columns: ['user_id'];
            isOneToOne: false;
            referencedRelation: 'profiles';
            referencedColumns: ['id'];
          },
        ];
      };
    };
    Functions: {
      challenge_group: {
        Args: { cid: string };
        Returns: string;
      };
      create_group: {
        Args: { p_name: string };
        Returns: string;
      };
      daily_draw: {
        Args: Record<PropertyKey, never>;
        Returns: undefined;
      };
      draw_challenge_for_group: {
        Args: { gid: string };
        Returns: undefined;
      };
      has_posted: {
        Args: { cid: string };
        Returns: boolean;
      };
      is_blocked_by_me: {
        Args: { uid: string };
        Returns: boolean;
      };
      is_current_challenge: {
        Args: { cid: string };
        Returns: boolean;
      };
      is_group_member: {
        Args: { gid: string };
        Returns: boolean;
      };
      join_group: {
        Args: { p_code: string };
        Returns: string;
      };
      monthly_top: {
        Args: { p_group: string; p_month: string };
        Returns: {
          meme_id: string;
          user_id: string;
          like_count: number;
          template_id: string;
          texts: Json;
        }[];
      };
      paris_today: {
        Args: Record<PropertyKey, never>;
        Returns: string;
      };
    };
    Enums: {
      [_ in never]: never;
    };
    CompositeTypes: {
      [_ in never]: never;
    };
  };
};

type PublicSchema = Database['public'];

export type Tables<T extends keyof (PublicSchema['Tables'] & PublicSchema['Views'])> =
  (PublicSchema['Tables'] & PublicSchema['Views'])[T] extends { Row: infer R } ? R : never;

export type TablesInsert<T extends keyof PublicSchema['Tables']> =
  PublicSchema['Tables'][T] extends { Insert: infer I } ? I : never;

export type TablesUpdate<T extends keyof PublicSchema['Tables']> =
  PublicSchema['Tables'][T] extends { Update: infer U } ? U : never;

export type FunctionArgs<T extends keyof PublicSchema['Functions']> =
  PublicSchema['Functions'][T]['Args'];

export type FunctionReturns<T extends keyof PublicSchema['Functions']> =
  PublicSchema['Functions'][T]['Returns'];
